//
//  SongViewModel.swift
//  Pod
//
//  Created by Iskren Alexandrov on 26.06.24.
//

import Combine
import Foundation
import AVFoundation

class SongViewModel: ObservableObject {
    var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    @Published private var songs: [Song]
    @Published private var currentSong: Int
    @Published private var update: Int = 0
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0.0
    var duration: TimeInterval = 0.0
    
    func loadAudioFile(_ path: String) {
        do {
            let url = URL(fileURLWithPath: path)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            startTimer()
            duration = audioPlayer?.duration ?? 0
            currentTime = 0
        } catch {
            print("Failed to load audio file: \(error.localizedDescription)")
        }
    }
    
    func playOrPause() {
        guard let player = audioPlayer else { return }
        
        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopTimer()
        } else {
            player.play()
            isPlaying = true
            
            startTimer()
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCurrentTime()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateCurrentTime() {
        guard let player = audioPlayer else { return }
        self.currentTime = player.currentTime
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedCurrentTime: String {
        return formatTime(currentTime)
    }
    
    var formattedDuration: String {
        return formatTime(duration)
    }
    
    init(loadUrl: String, currentSong: Int = 0) {
        self.songs = loadAudioFiles(from: loadUrl)
        self.currentSong = currentSong
        
        self.loadAudioFile(songs[currentSong].pathToAudioFile)
    }
    
    public func nextSong() {
        currentSong = (currentSong - 1 + songs.count) % songs.count
        self.loadAudioFile(songs[currentSong].pathToAudioFile)
        self.playOrPause()
    }
    
    public func prevSong() {
        currentSong = (currentSong - 1 + songs.count) % songs.count
        self.loadAudioFile(songs[currentSong].pathToAudioFile)
        self.playOrPause()
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
