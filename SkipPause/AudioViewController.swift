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
    case skipped
}

class AudioViewController: UIViewController {
    
    var originalPlayer: AVAudioPlayer?
    var skippedPlayer: AVAudioPlayer?
    
    var timer: Timer?
    var audioPlayerTimer: Timer?
    
    var secondsOfIncreasedPlayback = 0.0
    
    var typePlaying: TypePlaying = .original
    var nowPlaying: SoundFile?
    var decibelThreshold: Float = -40
    var samplingRate = 0.05
    
    let piano = SoundFile(resource: "piano")
    let ycombinator = SoundFile(resource: "ycombinator")
    let shouldWe = SoundFile(resource: "shouldwe")
    
    let playImage = UIImage(named: "Audio_Bar_Play")
    let pauseImage = UIImage(named: "Audio_Bar_Pause")
    
    @IBOutlet weak var originalTimestamp: UILabel?
    @IBOutlet weak var skippedTimestamp: UILabel?
    
    @IBOutlet weak var originalSeconds: UILabel?
    @IBOutlet weak var secondsSaved: UILabel?
    
    @IBOutlet weak var originalSlider: UISlider?
    @IBOutlet weak var skippedSlider: UISlider?
    
    @IBOutlet weak var originalPlayPauseButton: UIButton?
    @IBOutlet weak var skippedPlayPauseButton: UIButton?
    
    override func viewDidLoad() {
        nowPlaying = piano
        reset()
    }
    
    @IBAction func changedAudioClip(_ sender: UISegmentedControl) {
        reset()
        originalSeconds?.text = ""
        
        if sender.selectedSegmentIndex == 0 {
            nowPlaying = piano
        } else if sender.selectedSegmentIndex == 1 {
            nowPlaying = ycombinator
        } else if sender.selectedSegmentIndex == 2 {
            nowPlaying = shouldWe
        }
    }
    
    @IBAction func changeSamplingRate(_ sender: UISegmentedControl) {
        reset()
        if sender.selectedSegmentIndex == 0 {
            samplingRate = 0.05
        } else if sender.selectedSegmentIndex == 1 {
            samplingRate = 0.1
        } else if sender.selectedSegmentIndex == 2 {
            samplingRate = 0.2
        }
    }
    
    @IBAction func changedDecibelThreshold(_ sender: UISegmentedControl) {
        reset()
        if sender.selectedSegmentIndex == 0 {
            decibelThreshold = -40
        } else if sender.selectedSegmentIndex == 1 {
            decibelThreshold = -35
        } else if sender.selectedSegmentIndex == 2 {
            decibelThreshold = -30
        }
    }
    
    func reset() {
        originalPlayer = nil
        skippedPlayer = nil
        
        originalPlayPauseButton?.setImage(playImage, for: .normal)
        skippedPlayPauseButton?.setImage(playImage, for: .normal)

        secondsSaved?.text = "0 seconds saved"
        
        audioPlayerTimer?.invalidate()
        timer?.invalidate()
        
        originalSlider?.setValue(0, animated: true)
        skippedSlider?.setValue(0, animated: true)
        
        originalTimestamp?.text = 0.0.timeString()
        skippedTimestamp?.text = 0.0.timeString()
        
        secondsOfIncreasedPlayback = 0
    }
    
    @IBAction func playOriginalAudio(_ sender: UIButton) {
        skippedPlayer?.pause()
        skippedPlayPauseButton?.setImage(playImage, for: .normal)

        if let originalPlayer = originalPlayer {
            if originalPlayer.isPlaying {
                originalPlayer.pause()
                originalPlayPauseButton?.setImage(playImage, for: .normal)
            } else {
                originalPlayer.play()
                originalPlayPauseButton?.setImage(pauseImage, for: .normal)
            }
        } else {
            startOriginalAudio()
        }
    }

    func startOriginalAudio() {
        guard let nowPlaying = nowPlaying, let url = nowPlaying.playbackURL else {return }
        
        originalPlayer = try? AVAudioPlayer(contentsOf: url)
        originalPlayer?.delegate = self
        originalPlayer?.isMeteringEnabled = true
        originalPlayer?.enableRate = true
        
        if let duration = originalPlayer?.duration {
            originalSlider?.maximumValue = Float(duration)
            originalSlider?.minimumValue = 0.0
        }
        originalPlayer?.play()
        originalPlayPauseButton?.setImage(pauseImage, for: .normal)

        typePlaying = .original
        timer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(updateSlider), userInfo: nil, repeats: true)
    }
    
    @IBAction func playSkippedAudio(_ sender: UIButton) {
        originalPlayer?.pause()
        originalPlayPauseButton?.setImage(playImage, for: .normal)

        if let skippedPlayer = skippedPlayer {
            if skippedPlayer.isPlaying {
                skippedPlayer.pause()
                skippedPlayPauseButton?.setImage(playImage, for: .normal)
            } else {
                skippedPlayer.play()
                skippedPlayPauseButton?.setImage(pauseImage, for: .normal)
            }
        } else {
            startSkippedAudio()
        }
    }
    
    func startSkippedAudio() {
        guard let nowPlaying = nowPlaying, let url = nowPlaying.playbackURL else {return }
        
        skippedPlayer = try? AVAudioPlayer(contentsOf: url)
        skippedPlayer?.delegate = self
        skippedPlayer?.isMeteringEnabled = true
        skippedPlayer?.enableRate = true
        
        if let duration = skippedPlayer?.duration {
            skippedSlider?.maximumValue = Float(duration)
            skippedSlider?.minimumValue = 0.0
        }
        
        skippedPlayer?.play()
        skippedPlayPauseButton?.setImage(pauseImage, for: .normal)

        audioPlayerTimer = Timer.scheduledTimer(timeInterval: samplingRate, target: self, selector: #selector(updateRate), userInfo: nil, repeats: true)
        
        typePlaying = .skipped
        timer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(updateSlider), userInfo: nil, repeats: true)
    }
    
    @IBAction func scrubbedOriginalSlider(_ sender: UISlider) {
        originalPlayer?.currentTime = Double(sender.value)
        originalTimestamp?.text = Double(sender.value).timeString()
    }
    
    @IBAction func scrubbedSkippedSlider(_ sender: UISlider) {
        skippedPlayer?.currentTime = Double(sender.value)
        skippedTimestamp?.text = Double(sender.value).timeString()
        // need to play here?
    }
    
    func updateRate() {
        guard skippedPlayer?.isPlaying == true else { return }
        
        skippedPlayer?.updateMeters()
                
        if let averagePower = skippedPlayer?.averagePower(forChannel: 1),
            averagePower < decibelThreshold {
            skippedPlayer?.rate = 3
            secondsOfIncreasedPlayback += 0.1
            let totalSecondsSaved = (secondsOfIncreasedPlayback / 3).roundTo(places: 2)
            print("seconds saved: \(totalSecondsSaved)")
            secondsSaved?.text = ("\(totalSecondsSaved) seconds saved")
        } else {
            skippedPlayer?.rate = 1
        }
    }
    
    func updateSlider() {
        switch typePlaying {
        case .original:
            guard let seconds = originalPlayer?.currentTime else { return }
            originalSlider?.setValue(Float(seconds), animated: true)
            originalTimestamp?.text = "\(seconds.timeString())"
        case .skipped:
            guard let seconds = skippedPlayer?.currentTime else { return }
            skippedSlider?.setValue(Float(seconds), animated: true)
            skippedTimestamp?.text = "\(seconds.timeString())"
        }
    }
}

extension AudioViewController: AVAudioPlayerDelegate {
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if player == skippedPlayer {
            skippedPlayer = nil
            skippedPlayPauseButton?.setImage(playImage, for: .normal)
        } else if player == originalPlayer {
            originalPlayer = nil
            originalPlayPauseButton?.setImage(playImage, for: .normal)
        }
    }
}


extension Double {
    func roundTo(places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

extension TimeInterval {
    func timeString() -> String {
        let minutes = Int(self) / 60 % 60
        let seconds = Int(self) % 60
        return String(format:"%02i:%02i", minutes, seconds)
    }
}



