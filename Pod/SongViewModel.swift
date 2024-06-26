//
//  SongViewModel.swift
//  Pod
//
//  Created by Iskren Alexandrov on 26.06.24.
//

import Combine
import Foundation

class SongViewModel: ObservableObject {
    @Published private var songs: [Song]
    @Published private var currentSong: Int
    @Published public var audioPlayerViewModel = AudioPlayerViewModel()
    @Published private var update: Int = 0
    
    init(loadUrl: String, currentSong: Int = 0) {
        self.songs = loadAudioFiles(from: loadUrl)
        self.currentSong = currentSong
        
        audioPlayerViewModel.loadAudioFile(songs[currentSong].pathToAudioFile)
    }
        
    public func nextSong() {
        currentSong = (currentSong - 1 + songs.count) % songs.count
        audioPlayerViewModel.loadAudioFile(songs[currentSong].pathToAudioFile)
        audioPlayerViewModel.playOrPause()
    }
    
    public func prevSong() {
        currentSong = (currentSong - 1 + songs.count) % songs.count
        audioPlayerViewModel.loadAudioFile(songs[currentSong].pathToAudioFile)
        audioPlayerViewModel.playOrPause()
    }
    
    public func playPause() {
        audioPlayerViewModel.playOrPause()
    }
    
    public func getCurrentSongTitle() -> String {
        return songs[currentSong].title;
    }
    
    public func getCurrentSongArtist() -> String? {
        return songs[currentSong].artist;
    }
    
    public func getCurrentSongAlbum() -> String? {
        return songs[currentSong].album;
    }
}
