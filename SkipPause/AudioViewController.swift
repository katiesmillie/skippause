//
//  ViewController.swift
//  SkipPause
//
//  Created by Katie Smillie on 7/3/17.
//  Copyright © 2017 Katie Smillie. All rights reserved.
//

import UIKit
import AVFoundation

enum TypePlaying {
    case original
    case clipped
    case audioPlayer
}

class AudioViewController: UIViewController {
    
    var originalPlayer: AVPlayer?
    var clippedPlayer: AVPlayer?
    var audioPlayer: AVAudioPlayer?
    
    var reader: AssetReader?
    
    var timer: Timer?
    var audioPlayerTimer: Timer?
    
    var increasedPlayback: Int = 0
    
    var typePlaying: TypePlaying = .original
    
    var nowPlaying: SoundFile?
    
    
    let freakonomics = SoundFile(resource: "freakonomics")
    let notetoself = SoundFile(resource: "notetoself")
    let piano = SoundFile(resource: "piano")
    let brass = SoundFile(resource: "brass")
    let empty = SoundFile(resource: "empty")
    
    @IBOutlet weak var segementedControl: UISegmentedControl?
    
    @IBOutlet weak var originalSeconds: UILabel?
    @IBOutlet weak var clippedSeconds: UILabel?
    @IBOutlet weak var audioPlayerSeconds: UILabel?
    
    @IBOutlet weak var originalTotalSeconds: UILabel?
    @IBOutlet weak var clippedTotalSeconds: UILabel?
    @IBOutlet weak var secondsSaved: UILabel?
    
    @IBOutlet weak var originalSlider: UISlider?
    @IBOutlet weak var clippedSlider: UISlider?
    @IBOutlet weak var audioPlayerSlider: UISlider?


    override func viewDidLoad() {
        nowPlaying = piano
        clearLabels()
        setUpOriginal()
        
    }
    
    func setUpOriginal(){
        guard let nowPlaying = nowPlaying, let url = nowPlaying.playbackURL else {return }
        let playerItem = AVPlayerItem(url: url)
        originalPlayer = AVPlayer(playerItem: playerItem)
        self.originalTotalSeconds?.text = "\((playerItem.asset.duration.seconds).roundTo(places: 2)) seconds"
    }

    func updateRate() {
        guard audioPlayer?.isPlaying == true else {
            audioPlayerTimer!.invalidate()
            return
        }
        let decibelThreshold = Float(-35)
        
        audioPlayer?.updateMeters()
        
        let averagePower = audioPlayer?.averagePower(forChannel: 1)
        let peakPower = audioPlayer?.peakPower(forChannel: 1)
        
        if averagePower! < decibelThreshold {
            audioPlayer?.rate = 3
            increasedPlayback += 1
            let timeAtFasterRate = Double(increasedPlayback) * 0.1
            let seconds = (timeAtFasterRate - (timeAtFasterRate / 3)).roundTo(places: 2)
            print("seconds saved: \(seconds)")
            secondsSaved?.text = ("\(seconds) seconds saved")
        } else {
            audioPlayer?.rate = 1
        }
    }
    
    @IBAction func changedValue(_ sender: UISegmentedControl) {
        clearLabels()
        self.originalTotalSeconds?.text = ""

        if sender.selectedSegmentIndex == 0 {
            nowPlaying = piano
        } else if sender.selectedSegmentIndex == 1 {
            nowPlaying = brass
        } else if sender.selectedSegmentIndex == 2 {
            nowPlaying = freakonomics
        } else if sender.selectedSegmentIndex == 3 {
            nowPlaying = notetoself
        } else if sender.selectedSegmentIndex == 4 {
            nowPlaying = empty
        }
        setUpOriginal()
    }
    
    func clearLabels() {
        originalPlayer?.pause()
        clippedPlayer?.pause()
        audioPlayer?.pause()
        
        clippedTotalSeconds?.text = ""
        secondsSaved?.text = ""
        
        audioPlayerTimer?.invalidate()
        timer?.invalidate()
        
        clippedSlider?.setValue(0, animated: true)
        originalSlider?.setValue(0, animated: true)
        audioPlayerSlider?.setValue(0, animated: true)
        
        audioPlayerSeconds?.text = 0.0.timeString()
        originalSeconds?.text = 0.0.timeString()
        clippedSeconds?.text = 0.0.timeString()
        
        increasedPlayback = 0
    }
    
    @IBAction func tappedPlayeAudio(_ sender: UIButton) {
        originalPlayer?.pause()
        clippedPlayer?.pause()
        
        guard let nowPlaying = nowPlaying, let url = nowPlaying.playbackURL else {return }
        let playerItem = AVPlayerItem(url: url)
        let duration = playerItem.asset.duration.seconds
        
        self.audioPlayerSlider?.maximumValue = Float(duration)
        self.audioPlayerSlider?.minimumValue = 0.0
        
        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        audioPlayer?.isMeteringEnabled = true
        audioPlayer?.enableRate = true
        
        activateSmartSpeed()
        
        typePlaying = .audioPlayer
        timer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(updateSlider), userInfo: nil, repeats: true)
    }
    
    func activateSmartSpeed() {
        audioPlayer?.play()
        audioPlayerTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(updateRate), userInfo: nil, repeats: true)
    }
    
    @IBAction func tappedPlayOriginal(_ sender: UIButton) {
        audioPlayer?.pause()
        clippedPlayer?.pause()
        
        guard let nowPlaying = nowPlaying, let url = nowPlaying.playbackURL else {return }
        let playerItem = AVPlayerItem(url: url)
        originalPlayer = AVPlayer(playerItem: playerItem)
        self.originalTotalSeconds?.text = "\((playerItem.asset.duration.seconds).roundTo(places: 2)) seconds"
        
        let duration = playerItem.asset.duration.seconds
        originalSlider?.maximumValue = Float(duration)
        originalSlider?.minimumValue = 0.0
        originalPlayer?.play()
        
        originalPlayer?.play()

        
        typePlaying = .original
        timer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(updateSlider), userInfo: nil, repeats: true)
    }
    
    @IBAction func tappedPlayClipped(_ sender: UIButton) {
        audioPlayer?.pause()
        originalPlayer?.pause()
        clippedTotalSeconds?.text = "processing..."
        
        let typePlaying = self.typePlaying
        
        reader = AssetReader(soundFile: nowPlaying!) { playerItem in
            DispatchQueue.main.async {
                
                guard typePlaying == self.typePlaying else { return }
                guard let playerItem = playerItem else { return }
                self.clippedPlayer = AVPlayer(playerItem: playerItem)
                
                let duration = playerItem.asset.duration.seconds
                self.clippedSlider?.maximumValue = Float(duration)
                self.clippedSlider?.minimumValue = 0.0
                self.clippedTotalSeconds?.text = "\((playerItem.asset.duration.seconds).roundTo(places: 2)) seconds"
                
                self.clippedPlayer?.play()
                self.typePlaying = .clipped
                self.timer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(self.updateSlider), userInfo: nil, repeats: true)
            }
        }
        reader?.start()
    }
    
    @IBAction func scrubbedOriginalSlider(_ sender: UISlider) {
        let time = CMTime(seconds: Double(sender.value), preferredTimescale: 600)
        originalPlayer?.seek(to: time)
        originalSeconds?.text = time.seconds.timeString()
    }
    
    @IBAction func scrubbedClippedSlider(_ sender: UISlider) {
        let time = CMTime(seconds: Double(sender.value), preferredTimescale: 600)
        clippedPlayer?.seek(to: time)
        clippedSeconds?.text = time.seconds.timeString()
    }
    
    @IBAction func scrubbedAudioSlider(_ sender: UISlider) {
        audioPlayer?.currentTime = Double(sender.value)
        audioPlayerSeconds?.text = Double(sender.value).timeString()
        clearLabels()
        activateSmartSpeed()
    }
    
    func updateSlider() {
        switch typePlaying{
        case .clipped:
            guard let seconds = clippedPlayer?.currentTime().seconds else { return }
            clippedSlider?.setValue(Float(seconds), animated: true)
            self.clippedSeconds?.text = "\(seconds.timeString())"
        case .original:
            guard let seconds = originalPlayer?.currentTime().seconds else { return }
            originalSlider?.setValue(Float(seconds), animated: true)
            self.originalSeconds?.text = "\(seconds.timeString())"
        case .audioPlayer:
            guard let seconds = audioPlayer?.currentTime else { return }
            audioPlayerSlider?.setValue(Float(seconds), animated: true)
            self.audioPlayerSeconds?.text = "\(seconds.timeString())"
        }
    }
    
}

extension TimeInterval {
    func timeString() -> String {
        let minutes = Int(self) / 60 % 60
        let seconds = Int(self) % 60
        return String(format:"%02i:%02i", minutes, seconds)
    }
}


extension Double {
    /// Rounds the double to decimal places value
    func roundTo(places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}


