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
import TelemetryDeck

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
    
    var isRadioStation = false
    var currentRadioName = ""
    var streamPlayer: AVPlayer?
    
    init()
    {
        self.setupRemoteCommandCenter()
    }
    
    func loadAudioFile(_ path: String) {
        // Stop any existing radio playback
        streamPlayer?.pause()
        streamPlayer = nil
        isRadioStation = false
        
        do {
            let url = URL(fileURLWithPath: path)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            startTimer()
            duration = audioPlayer?.duration ?? 0
            currentTime = 0
            audioPlayer?.volume = 0.6
            
            TelemetryDeck.signal("Song.play", parameters: ["songName": songs[currentSong].title, "artist": songs[currentSong].artist ?? ""])
        } catch {
            print("Failed to load audio file: \(error.localizedDescription)")
        }
    }
    
    func playRadioStation(url: String, name: String) {
        // Stop any existing playback
        audioPlayer?.stop()
        audioPlayer = nil
        streamPlayer?.pause()
        streamPlayer = nil
        
        guard let streamURL = URL(string: url) else {
            print("Invalid stream URL")
            return
        }
        
        // Create an AVPlayerItem with the stream URL
        let playerItem = AVPlayerItem(url: streamURL)
        streamPlayer = AVPlayer(playerItem: playerItem)
        
        currentRadioName = name
        isRadioStation = true
        duration = 0
        currentTime = 0
        
        // Switch to song view before playing
        GlobalState.shared.activeView = .song
        
        // Start playing
        streamPlayer?.play()
        isPlaying = true
        
        updateNowPlayingInfo()
        TelemetryDeck.signal("Radio.play", parameters: ["stationName": name])
    }
    
    func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        
        if isRadioStation {
            nowPlayingInfo[MPMediaItemPropertyTitle] = currentRadioName
            nowPlayingInfo[MPMediaItemPropertyArtist] = "Live Radio"
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = 0.0
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0.0
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
            
            // Add a radio icon for radio stations
            if let radioIcon = NSImage(systemSymbolName: "radio", accessibilityDescription: nil) {
                let artwork = MPMediaItemArtwork(boundsSize: radioIcon.size) { size in
                    radioIcon
                }
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            }
        } else {
            nowPlayingInfo[MPMediaItemPropertyTitle] = songs[currentSong].title
            nowPlayingInfo[MPMediaItemPropertyArtist] = songs[currentSong].artist
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = audioPlayer?.duration ?? 0.0
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioPlayer?.currentTime ?? 0.0
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = (audioPlayer?.isPlaying ?? false) ? 1.0 : 0.0
            
            if let songImage = songs[currentSong].coverImage {
                let albumArt = MPMediaItemArtwork(boundsSize: songImage.size) { size in
                    songImage
                }
                nowPlayingInfo[MPMediaItemPropertyArtwork] = albumArt
            }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
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
        // Clean up when going back to album view
        if isRadioStation {
            streamPlayer?.pause()
            streamPlayer = nil
        } else {
            audioPlayer?.stop()
            audioPlayer = nil
        }
        isPlaying = false
        isRadioStation = false
        currentRadioName = ""
        GlobalState.shared.activeView = .albums
    }
    
    deinit {
        stopTimer()
        streamPlayer?.pause()
        streamPlayer = nil
        audioPlayer?.stop()
        audioPlayer = nil
    }
}
