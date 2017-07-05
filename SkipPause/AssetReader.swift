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
    var samplesWithTimes: [(CGFloat, CMTime)] = []
    var playerItem: AVPlayerItem?
    
    var decibelThreshold: CGFloat = 60
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
        fetchSamples2(from: asset)
        let item = createComposition(asset: asset)
        finish(with: item)
    }
    
    func createComposition(asset: AVAsset) -> AVPlayerItem {
        
//        // Try calculating sampleDuration by the difference between consecutive samples
//        // vs the formula from the documentation
//        if presentationTimes.count > 1 {
//            sampleDuration = presentationTimes[1].seconds - presentationTimes[0].seconds
//        }
//        
        
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
    
    func createComposition2(asset: AVAsset) -> AVPlayerItem {
        
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
    
    
    func fetchSamples2(from asset: AVAsset) {
        
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
        
        var sampleData = Data()
        
        // 16-bit samples
        reader.startReading()
        defer { reader.cancelReading() } // Cancel reading if we exit early if operation is cancelled
        
        while reader.status == .reading {
            guard !isCancelled else { return }
            
            guard let readSampleBuffer = readerOutput.copyNextSampleBuffer(),
                let readBuffer = CMSampleBufferGetDataBuffer(readSampleBuffer) else { break }
            
            
            var audioBufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: UInt32(channelCount), mDataByteSize: 0, mData: nil))
            
            var blockBuffer: CMBlockBuffer? = nil
            
            CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(readSampleBuffer, nil, &audioBufferList, MemoryLayout<AudioBufferList>.size, nil, nil, UInt32(kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment), &blockBuffer)
       
            let presentationTime: CMTime? = CMSampleBufferGetPresentationTimeStamp(readSampleBuffer)
            print(presentationTime?.seconds)

            var sampleOutput: [Int16] = []
            
            let audioBufferListPointer = UnsafeMutableAudioBufferListPointer(&audioBufferList)
            
            audioBufferListPointer.forEach { buffer in
                let samples = UnsafeMutableBufferPointer<Int16>(start: UnsafeMutablePointer(OpaquePointer(buffer.mData)),
                                                                count: Int(buffer.mDataByteSize)/MemoryLayout<Int16>.size)
                
                samples.forEach { sample in
                    sampleOutput += [sample]
                }
                
            }
            
            let max = Int(sampleOutput.max()!)
            print(max)
            print(abs(max))
            
            
            if decibel(CGFloat(max)) < decibelThreshold {
                presentationTimes += [presentationTime!]
            }
            
        }
        
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
        
        var sampleData = Data()
        
        // 16-bit samples
        reader.startReading()
        defer { reader.cancelReading() } // Cancel reading if we exit early if operation is cancelled
        
        while reader.status == .reading {
            guard !isCancelled else { return }
            
            guard let readSampleBuffer = readerOutput.copyNextSampleBuffer(),
                let readBuffer = CMSampleBufferGetDataBuffer(readSampleBuffer) else { break }
            
            
            
            // Using CMBlockBufferCopyDataBytes
            let length = CMBlockBufferGetDataLength(readBuffer)
            
            let data = NSMutableData(length: length)
            CMBlockBufferCopyDataBytes(readBuffer, 0, length, data!.mutableBytes)
            let samples = data?.mutableBytes.assumingMemoryBound(to: UInt8.self)
            sampleData.append(samples!, count: length)
            let presentationTime: CMTime? = CMSampleBufferGetPresentationTimeStamp(readSampleBuffer)
            
            CMSampleBufferInvalidate(readSampleBuffer)
            
            print("episode: \(soundFile.resource) -- sample data \(sampleData.count) -- presentation time \(presentationTime!.seconds)")
            
            
            // Using CMBlockBufferGetDataPointer
            var readBufferLength = 0
            var readBufferPointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(readBuffer, 0, &readBufferLength, nil, &readBufferPointer)
            
            sampleBuffer.append(UnsafeBufferPointer(start: readBufferPointer, count: readBufferLength))
            //            let presentationTime: CMTime? = CMSampleBufferGetPresentationTimeStamp(readSampleBuffer)
            CMSampleBufferInvalidate(readSampleBuffer)
            
            print("episode: \(soundFile.resource) -- sample buffer \(sampleBuffer.count) -- presentation time \(presentationTime!.seconds)")
            
            
            
            // Use sampleBuffer or sampleData
            let totalSamples = sampleData.count / MemoryLayout<UInt8>.size
            
            let downSampledLength = totalSamples / adjustedRate
            //            let samplesToProcess = downSampledLength * adjustedRate
            //            guard samplesToProcess > 0 else { continue }
            
            // Pass in totalSamples for samplesToProcess to process when NOT downsampling
            let samplesToProcess = totalSamples
            
            processSamples(fromData: &sampleData,
                           outputSamples: &outputSamples,
                           samplesToProcess: samplesToProcess,
                           downSampledLength: downSampledLength,
                           adjustedRate: adjustedRate,
                           filter: filter,
                           presentationTime: presentationTime)
        }
        
        if reader.status == .completed {
            
            //            normalize()
        }
        
        if reader.status == .failed {
            print("Failed to read audio: \(String(describing: reader.error))")
        }
    }
    
    func normalize() {
        // Tried normalizing all the data and then filtering because the decibel level
        // seemed to be relative to the file rather than consistent
        
        let filterThreshold: CGFloat = 0.10
        
        let max = Int32(samplesWithTimes.map { $0.0 }.max()!)
        let min = Int32(samplesWithTimes.map { $0.0 }.min()!)
        let minAbsolute = abs(min)
        let newMax = max + minAbsolute
        let newMin = min + minAbsolute
        
        let normalizedData = samplesWithTimes.map { amplitude, time -> (CGFloat, CMTime) in
            let normalized = CGFloat((Int32(amplitude) + minAbsolute) - newMin) / CGFloat(newMax - newMin)
            print(normalized, time.seconds)
            return (normalized, time)
        }
        
        presentationTimes = normalizedData.filter { $0.0 < filterThreshold }.map { $0.1 }
        
        
    }
    
    func processSamples(fromData sampleBuffer: inout Data, outputSamples: inout [CGFloat], samplesToProcess: Int, downSampledLength: Int, adjustedRate: Int, filter: [Float], presentationTime: CMTime?) {
        
        sampleBuffer.withUnsafeBytes { (samples: UnsafePointer<Int8>) in
            
            var processingBuffer = [Float](repeating: 0.0, count: samplesToProcess)
            
            let sampleCount = vDSP_Length(samplesToProcess)
            
            //Convert 16bit int samples to floats
            vDSP_vflt8(samples, 1, &processingBuffer, 1, sampleCount)
            
            //Take the absolute values to get amplitude
            vDSP_vabs(processingBuffer, 1, &processingBuffer, 1, sampleCount)
            
            //Downsample and average
            //            var downSampledData = [Float](repeating: 0.0, count: downSampledLength)
            //            vDSP_desamp(processingBuffer,
            //                        vDSP_Stride(adjustedRate),
            //                        filter,
            //                        &downSampledData,
            //                        vDSP_Length(downSampledLength),
            //                        vDSP_Length(adjustedRate))
            //
            
            // Use downSampledData instead of processingBuffer when downsampling
            let downSampledDataCG = processingBuffer.map { CGFloat($0) }
            
            // Remove processed samples
            sampleBuffer.removeFirst(samplesToProcess * MemoryLayout<UInt8>.size)
            
            if let amplitude = downSampledDataCG.max() {
                samplesWithTimes += [(amplitude, presentationTime!)]
                print(amplitude, presentationTime!)
            }
            
            
            if decibel(downSampledDataCG.max()!) < decibelThreshold {
                presentationTimes += [presentationTime!]
            }
            
            
        }
    }
    
    func decibel(_ amplitude: CGFloat) -> CGFloat {
        if amplitude == 0 { return 0 }
        return 20.0 * log10(abs(amplitude))
    }
    
}


