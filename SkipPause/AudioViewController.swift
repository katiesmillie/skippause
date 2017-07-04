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
}

class AudioViewController: UIViewController {
    
    var originalPlayer: AVPlayer?
    var clippedPlayer: AVPlayer?
    
    var reader: AssetReader?
    
    var timer: Timer?
    
    let freakonomics = SoundFile(resource: "freakonomics")
    let notetoself = SoundFile(resource: "notetoself")
    let piano = SoundFile(resource: "piano")
    let brass = SoundFile(resource: "brass")

    @IBOutlet weak var segementedControl: UISegmentedControl?
    
    @IBOutlet weak var originalSeconds: UILabel?
    @IBOutlet weak var clippedSeconds: UILabel?
    
    @IBOutlet weak var originalTotalSeconds: UILabel?
    @IBOutlet weak var clippedTotalSeconds: UILabel?
    
    @IBOutlet weak var originalSlider: UISlider?
    @IBOutlet weak var clippedSlider: UISlider?
    
    var typePlaying: TypePlaying = .original
    
    var nowPlaying: SoundFile?
    
    override func viewDidLoad() {
        setUpPlayer()
    }
    
    func setUpPlayer() {
        // setup original
        guard let nowPlaying = nowPlaying, let url = nowPlaying.playbackURL else {return }
        let playerItem = AVPlayerItem(url: url)
        originalPlayer = AVPlayer(playerItem: playerItem)
        self.originalTotalSeconds?.text = "\(playerItem.asset.duration.seconds) seconds"
        
        let duration = playerItem.asset.duration.seconds
        originalSlider?.maximumValue = Float(duration)
        originalSlider?.minimumValue = 0.0
        
        //setup clipped
        reader = AssetReader(soundFile: nowPlaying) { playerItem in
            DispatchQueue.main.async {
                guard let playerItem = playerItem else { return }
                self.clippedPlayer = AVPlayer(playerItem: playerItem)
                
                let duration = playerItem.asset.duration.seconds
                self.clippedSlider?.maximumValue = Float(duration)
                self.clippedSlider?.minimumValue = 0.0
                self.clippedTotalSeconds?.text = "\(playerItem.asset.duration.seconds) seconds"
            }
        }
        reader?.start()
    }
    
    @IBAction func changedValue(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            nowPlaying = piano
        } else if sender.selectedSegmentIndex == 1 {
            nowPlaying = brass
        } else if sender.selectedSegmentIndex == 2 {
            nowPlaying = freakonomics
        } else if sender.selectedSegmentIndex == 3 {
            nowPlaying = notetoself
        }
        setUpPlayer()
    }
    
    @IBAction func tappedPlayOriginal(_ sender: UIButton) {
        originalPlayer?.play()
        typePlaying = .original
        timer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(updateSlider), userInfo: nil, repeats: true)
    }
    
    @IBAction func tappedPlayClipped(_ sender: UIButton) {
        clippedPlayer?.play()
        typePlaying = .clipped
        timer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(updateSlider), userInfo: nil, repeats: true)
    }
    
    @IBAction func scrubbedOriginalSlider(_ sender: UISlider) {
        let time = CMTime(seconds: Double(sender.value), preferredTimescale: 600)
        originalPlayer?.seek(to: time)
    }
    
    @IBAction func scrubbedClippedSlider(_ sender: UISlider) {
        let time = CMTime(seconds: Double(sender.value), preferredTimescale: 600)
        clippedPlayer?.seek(to: time)
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


