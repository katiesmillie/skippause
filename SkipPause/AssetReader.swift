//
//  AssetReader.swift
//  Breaker
//
//  Created by Katie Smillie on 6/28/17.
//  Copyright © 2017 Breaker. All rights reserved.
//

import UIKit
import AVFoundation
import Accelerate

class AssetReader: Operation {
    
    // MARK: - NSOperation Overrides
    
    public override var isAsynchronous: Bool { return true }
    
    private var _isExecuting = false
    public override var isExecuting: Bool { return _isExecuting }
    
    private var _isFinished = false
    public override var isFinished: Bool { return _isFinished }
    
    private let completionHandler: (_ item: AVPlayerItem?) -> ()
    
    var soundFile: SoundFile
    var presentationTimes: [CMTime] = []
    var playerItem: AVPlayerItem?
    
    var decibelThreshold: CGFloat = 40
    var sampleDuration: Double?
    
    init(soundFile: SoundFile, completionHandler: @escaping (_ item: AVPlayerItem?) -> ()) {
        self.soundFile = soundFile
        self.completionHandler = completionHandler
        
        super.init()
        
        self.completionBlock = { [weak self] in
            guard let `self` = self else { return }
            self.completionHandler(self.playerItem)
        }
    }
    
    public override func start() {
        guard !isExecuting && !isFinished && !isCancelled else { return }
        
        willChangeValue(forKey: "isExecuting")
        _isExecuting = true
        didChangeValue(forKey: "isExecuting")
        
        DispatchQueue.global(qos: .background).async { self.render() }
    }
    
    private func finish(with item: AVPlayerItem?) {
        guard !isFinished && !isCancelled else { return }
        
        playerItem = item
        
        // completionBlock called automatically by NSOperation after these values change
        willChangeValue(forKey: "isExecuting")
        willChangeValue(forKey: "isFinished")
        _isExecuting = false
        _isFinished = true
        didChangeValue(forKey: "isExecuting")
        didChangeValue(forKey: "isFinished")
    }
    
    private func render() {
        guard let url = soundFile.playbackURL else { return }
        let asset = AVAsset(url: url)
        fetchSamples(from: asset)
        let item = createComposition(asset: asset)
        finish(with: item)
    }
    
    func createComposition(asset: AVAsset) -> AVPlayerItem {
        let mutableComposition = AVMutableComposition()
        
        let type = AVMediaTypeAudio
        let prefTrackID = kCMPersistentTrackID_Invalid
        
        let sourceTrack: AVAssetTrack = asset.tracks(withMediaType: type).first!
        let newTrack = mutableComposition.addMutableTrack(withMediaType: type, preferredTrackID: prefTrackID)
        print(newTrack.asset!.duration.seconds)
        
        do {
            let startTime = kCMTimeZero
            let duration = asset.duration
            let range = CMTimeRangeMake(startTime, duration)
            try newTrack.insertTimeRange(range, of: sourceTrack, at: startTime)
            print(newTrack.asset!.duration.seconds)
        } catch { print(error) }
        
        print(presentationTimes.count)
        presentationTimes.forEach { time in
            
            let startTime = time
            let duration = CMTime(seconds: sampleDuration!, preferredTimescale: 600)
            let range = CMTimeRangeMake(startTime, duration)
            newTrack.removeTimeRange(range)
            
        }
        print(newTrack.asset!.duration.seconds)
        return AVPlayerItem(asset: mutableComposition)
    }
    
    // Read the asset and create create a lower resolution set of samples
    func fetchSamples(from asset: AVAsset) {
        guard !isCancelled else { return }
        
        guard
            let track = asset.tracks(withMediaType: AVMediaTypeAudio).first,
            let reader = try? AVAssetReader(asset: asset)
            else { return }
        
        let outputSettingsDict: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        
        let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettingsDict)
        readerOutput.alwaysCopiesSampleData = false
        reader.add(readerOutput)
        
        var channelCount = 1
        var sampleRate = 0.0
        var framesPerPacket: Float64 = 0
        
        let formatDescriptions = track.formatDescriptions as! [CMAudioFormatDescription]
        for item in formatDescriptions {
            guard let formatDescription = CMAudioFormatDescriptionGetStreamBasicDescription(item) else { return }
            sampleRate = formatDescription.pointee.mSampleRate // 44100
            channelCount = Int(formatDescription.pointee.mChannelsPerFrame)
            framesPerPacket = Float64(formatDescription.pointee.mFramesPerPacket) // 1152
        }
        
        sampleDuration = (1 / sampleRate) * framesPerPacket
        
        var adjustedRate: Int = Int(sampleRate)
        
        let filter = [Float](repeating: 1.0 / Float(adjustedRate), count: adjustedRate)
        
        var outputSamples = [CGFloat]()
        var sampleBuffer = Data()
        
        // 16-bit samples
        reader.startReading()
        defer { reader.cancelReading() } // Cancel reading if we exit early if operation is cancelled
        
        while reader.status == .reading {
            guard !isCancelled else { return }
            
            guard let readSampleBuffer = readerOutput.copyNextSampleBuffer(),
                let readBuffer = CMSampleBufferGetDataBuffer(readSampleBuffer) else {
                    break
            }
            
            // Append audio sample buffer into our current sample buffer
            var readBufferLength = 0
            var readBufferPointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(readBuffer, 0, &readBufferLength, nil, &readBufferPointer)
            
            sampleBuffer.append(UnsafeBufferPointer(start: readBufferPointer, count: readBufferLength))
            let presentationTime: CMTime? = CMSampleBufferGetPresentationTimeStamp(readSampleBuffer)
            CMSampleBufferInvalidate(readSampleBuffer)
            
            print("episode: \(soundFile.resource) -- sample buffer \(sampleBuffer.count) -- presentation time \(presentationTime!.seconds)")
            
            let totalSamples = sampleBuffer.count / MemoryLayout<Int16>.size
            
            let downSampledLength = totalSamples / adjustedRate
            let samplesToProcess = downSampledLength * adjustedRate
            guard samplesToProcess > 0 else { continue }
            
            processSamples(fromData: &sampleBuffer,
                           outputSamples: &outputSamples,
                           samplesToProcess: samplesToProcess,
                           downSampledLength: downSampledLength,
                           adjustedRate: adjustedRate,
                           filter: filter,
                           presentationTime: presentationTime)
        }
        
        if reader.status == .failed {
            print("Failed to read audio: \(String(describing: reader.error))")
        }
    }
    
    func processSamples(fromData sampleBuffer: inout Data, outputSamples: inout [CGFloat], samplesToProcess: Int, downSampledLength: Int, adjustedRate: Int, filter: [Float], presentationTime: CMTime?) {
        
        sampleBuffer.withUnsafeBytes { (samples: UnsafePointer<Int16>) in
            
            var processingBuffer = [Float](repeating: 0.0, count: samplesToProcess)
            
            let sampleCount = vDSP_Length(samplesToProcess)
            
            //Convert 16bit int samples to floats
            vDSP_vflt16(samples, 1, &processingBuffer, 1, sampleCount)
            
            //Take the absolute values to get amplitude
            vDSP_vabs(processingBuffer, 1, &processingBuffer, 1, sampleCount)
            
            //Downsample and average
            var downSampledData = [Float](repeating: 0.0, count: downSampledLength)
            vDSP_desamp(processingBuffer,
                        vDSP_Stride(adjustedRate),
                        filter,
                        &downSampledData,
                        vDSP_Length(downSampledLength),
                        vDSP_Length(adjustedRate))
            
            
            let downSampledDataCG = downSampledData.map { CGFloat($0) }
            
            // Remove processed samples
            sampleBuffer.removeFirst(samplesToProcess * MemoryLayout<Int16>.size)
            
            let maxDecibel = decibel(downSampledDataCG.max()!)
            
            print("max decibel: \(maxDecibel) -- presentation time \(presentationTime!.seconds) *************************")
            
            if maxDecibel < decibelThreshold, let presentationTime = presentationTime {
                presentationTimes += [presentationTime]
            }
            outputSamples += downSampledDataCG
        }
    }
    
    func decibel(_ amplitude: CGFloat) -> CGFloat {
        if amplitude == 0 { return 0 }
        return 20.0 * log10(abs(amplitude))
    }
    
}


