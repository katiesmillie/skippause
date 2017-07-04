//
//  SoundFile.swift
//  SkipPause
//
//  Created by Katie Smillie on 7/4/17.
//  Copyright © 2017 Katie Smillie. All rights reserved.
//

import Foundation
import AVFoundation

class SoundFile {
    
    var resource: String
    var playbackURL: URL?
    var playerItem: AVPlayerItem?
    var audioFilePath: String?
    
    init(resource: String) {
        self.resource = resource
        
        audioFilePath = Bundle.main.path(forResource: resource, ofType: "mp3")
        
        guard let audioFilePath = audioFilePath else { return }
        playbackURL = URL(fileURLWithPath: audioFilePath)
    }
    
    func downloadSize() -> Double? {
        guard let path = audioFilePath else { return nil }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            guard let fileSize: UInt64 = (attributes[FileAttributeKey.size] as? NSNumber)?.uint64Value else { return nil }
            return Double(fileSize)
        } catch let error as NSError {
            print("Error accessing file download size: \(error.localizedDescription)")
        }
        return nil
    }
}
