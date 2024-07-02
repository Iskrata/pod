//
//  SongViewModel.swift
//  Pod
//
//  Created by Iskren Alexandrov on 26.06.24.
//

import Combine
import Foundation
import AVFoundation

class SongViewModel: ProtocolView {
    var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    @Published var songs: [Song] = [Song(title: "Example Song", pathToAudioFile: "")]
    @Published var currentSong: Int = 0
    @Published private var update: Int = 0
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0.0
    var duration: TimeInterval = 0.0
    
//    init(currentSong: Int = 0) {
//        self.songs = loadAudioFiles(from: loadUrl)
//        self.currentSong = currentSong
//        
//        self.loadAudioFile(songs[currentSong].pathToAudioFile)
//    }
    
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
    
    
    public func getCurrentSongTitle() -> String {
        return songs[currentSong].title;
    }
    
    public func getCurrentSongArtist() -> String? {
        return songs[currentSong].artist;
    }
    
    public func getCurrentSongAlbum() -> String? {
        return songs[currentSong].album;
    }
    
    func nextClick() {
        currentSong = (currentSong + 1) % songs.count
        self.loadAudioFile(songs[currentSong].pathToAudioFile)
        self.playPauseClick()
    }

    func prevClick() {
        currentSong = (currentSong - 1 + songs.count) % songs.count
        self.loadAudioFile(songs[currentSong].pathToAudioFile)
        self.playPauseClick()
    }
    
    func playPauseClick() {
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
    
    
    func middleClick() {
        
    }
    
    func wheelUp() {
        
    }
    
    func wheelDown() {
        
    }
}
