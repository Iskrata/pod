//
//  Song.swift
//  Pod
//
//  Created by Iskren Alexandrov on 22.06.24.
//

import Foundation

struct Song: Identifiable {
    
    let id = UUID()
    var title: String
    var artist: String?
    var album: String?
    var pathToAudioFile: String
    var pathToImageFile: String?
    
    init(title: String, artist: String? = nil, album: String? = nil, pathToAudioFile: String, pathToImageFile: String? = nil) {
        self.title = title
        self.artist = artist
        self.album = album
        self.pathToAudioFile = pathToAudioFile
        self.pathToImageFile = pathToImageFile
    }
    
}
