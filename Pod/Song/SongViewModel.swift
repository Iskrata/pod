//
//  SongViewModel.swift
//  Pod
//
//  Created by Iskren Alexandrov on 26.06.24.
//

import Combine
import Foundation
import AVFoundation
import SwiftUI
import MediaPlayer

class SongViewModel: ProtocolView {
    var view: AnyView {
        AnyView(SongView(viewModel: self))
    }
    
    var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private let hapticManager = NSHapticFeedbackManager.defaultPerformer
    
    // TODO: Make it to empty list
    @Published var songs: [Song] = [Song(title: "Example Song", pathToAudioFile: "")]
    @Published var currentSong: Int = 0
    @Published private var update: Int = 0
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0.0
    var duration: TimeInterval = 0.0
    
    init()
    {
        self.setupRemoteCommandCenter()
    }
    
    func loadAudioFile(_ path: String) {
        do {
            let url = URL(fileURLWithPath: path)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            startTimer()
            duration = audioPlayer?.duration ?? 0
            currentTime = 0
            audioPlayer?.volume = 0.6
        } catch {
            print("Failed to load audio file: \(error.localizedDescription)")
        }
    }
    
    func updateNowPlayingInfo() {
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = songs[currentSong].title
        nowPlayingInfo[MPMediaItemPropertyArtist] = songs[currentSong].artist
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = audioPlayer?.duration ?? 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioPlayer?.currentTime ?? 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = (audioPlayer?.isPlaying ?? false) ? 1.0 : 0.0
        
        let songImage: NSImage? = songs[currentSong].coverImage
        if (songImage != nil) {
            let albumArt: MPMediaItemArtwork = MPMediaItemArtwork(boundsSize: songImage!.size) { size in
                songImage!
            }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = albumArt
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
            print("togglePlayPauseCommand")
            self?.playPauseClick()
            return .success
        }
        
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
            self?.nextClick()
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
            self?.prevClick()
            return .success
        }
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
            print("playCommand")
            self?.playPauseClick()
            return .success
        }
        
        updateNowPlayingInfo()
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
        self.updateNowPlayingInfo()
        
        if (player.currentTime >= player.duration - 1.0)
        {
            self.nextClick()
        }
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
            MPNowPlayingInfoCenter.default().playbackState = .paused
        } else {
            player.play()
            isPlaying = true
            startTimer()
            MPNowPlayingInfoCenter.default().playbackState = .playing
        }
        
        updateNowPlayingInfo()
    }
    
    
    func middleClick() {
        
    }
    
    func wheelUp() {
        guard let player = audioPlayer else { return }
        
        if (self.currentTime > 0.0) {
            player.currentTime -= 5
            self.currentTime -= 5
            
            if (self.currentTime < 0) {
                self.currentTime = 0
            }
            self.hapticManager.perform(.levelChange, performanceTime: .default)
        }
        
    }
    
    func wheelDown() {
        guard let player = audioPlayer else { return }
        if (self.currentTime < self.duration) {
            player.currentTime += 5
            self.currentTime += 5
            
            if (self.currentTime > self.duration)
            {
                self.currentTime = self.duration
            }
            self.hapticManager.perform(.levelChange, performanceTime: .default)
        }
        
    }
    
    func menuClick() {
        GlobalState.shared.activeView = .albums
    }
}
