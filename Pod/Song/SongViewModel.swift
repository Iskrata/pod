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

    // Spotify
    @Published var isSpotifyPlayback = false
    @Published var spotifyTracks: [SpotifyTrack] = []
    @Published var currentSpotifyTrackIndex: Int = 0
    @Published var currentSpotifyPlaylistId: String = ""
    @Published var currentSpotifyPlaylistName: String = ""
    @Published var currentSpotifyImageUrl: String?
    
    init() {
        self.setupRemoteCommandCenter()
        setupSpotifyObserver()
    }

    private func setupSpotifyObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(spotifyStateChanged),
            name: NSNotification.Name("SpotifyStateChanged"),
            object: nil
        )
    }

    @objc private func spotifyStateChanged(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isSpotifyPlayback else { return }
            let service = SpotifyService.shared
            let wasPlaying = self.isPlaying
            let spotifyTime = service.currentTrackPosition
            let spotifyDuration = service.currentTrackDuration

            self.isPlaying = service.isPlaying
            // Only adopt the bridge's duration if it's a real value;
            // otherwise keep whatever was set from track.durationMs.
            if spotifyDuration > 0 {
                self.duration = spotifyDuration
            }

            // Sync time from Spotify only on significant drift (>3s)
            // Local timer is primary source, Spotify corrects drift
            if spotifyTime > 1.0 {
                if abs(self.currentTime - spotifyTime) > 3.0 {
                    self.currentTime = spotifyTime
                }
            }

            // Manage timer based on play state
            if service.isPlaying && !wasPlaying {
                self.startSpotifyTimer()
            } else if !service.isPlaying && wasPlaying {
                self.stopSpotifyTimer()
            }

            // Handle track changes from Spotify (e.g., auto-advance)
            if let userInfo = notification.userInfo,
               let trackChanged = userInfo["trackChanged"] as? Bool,
               trackChanged,
               let currentTrackId = service.currentTrackId {
                // Find the track in our list and update index
                if let index = self.spotifyTracks.firstIndex(where: { $0.id == currentTrackId }) {
                    self.currentSpotifyTrackIndex = index
                }
            }

            // Auto-advance when track ends. The bridge sends an explicit
            // "track_end" event (forwarded as trackEnded=true). Also keep a
            // heuristic against self.duration (which we trust from track.durationMs)
            // since service.currentTrackDuration is unreliable.
            let explicitEnd = (notification.userInfo?["trackEnded"] as? Bool) == true
            let heuristicEnd = wasPlaying && !service.isPlaying && self.duration > 0 && (
                self.currentTime >= self.duration - 1.0 ||
                (spotifyTime == 0 && self.lastSpotifyPosition >= self.duration - 2.0)
            )
            if explicitEnd || heuristicEnd {
                NSLog("[SongVM] auto-advance (explicit=\(explicitEnd) heuristic=\(heuristicEnd))")
                self.nextClick()
            }

            self.lastSpotifyPosition = spotifyTime

            self.updateNowPlayingInfo()
        }
    }

    private var spotifyTimer: Timer?
    private var lastSpotifyPosition: TimeInterval = 0

    private func startSpotifyTimer() {
        spotifyTimer?.invalidate()
        spotifyTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isSpotifyPlayback, self.isPlaying else { return }
            self.currentTime += 1.0
            if self.currentTime > self.duration { self.currentTime = self.duration }
            self.updateNowPlayingInfo()
        }
    }

    private func stopSpotifyTimer() {
        spotifyTimer?.invalidate()
        spotifyTimer = nil
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

    func playSpotifyPlaylist(playlistId: String, playlistName: String, imageUrl: String?) {
        NSLog("[SongVM] playSpotifyPlaylist name=\(playlistName) id=\(playlistId)")
        stopAllPlayback()

        isSpotifyPlayback = true
        currentSpotifyPlaylistId = playlistId
        currentSpotifyPlaylistName = playlistName
        currentSpotifyImageUrl = imageUrl
        currentSpotifyTrackIndex = 0

        GlobalState.shared.activeView = .song

        Task {
            let tracks = await SpotifyService.shared.fetchPlaylistTracks(playlistId: playlistId)
            await MainActor.run {
                self.spotifyTracks = tracks
                if !tracks.isEmpty {
                    self.waitForPlayerAndPlay(trackIndex: 0)
                }
            }
        }

        TelemetryDeck.signal("Spotify.play", parameters: ["playlistName": playlistName])
    }

    func playSpotifyAlbum(albumId: String, albumUri: String, albumName: String, imageUrl: String?) {
        NSLog("[SongVM] playSpotifyAlbum name=\(albumName) id=\(albumId) uri=\(albumUri)")
        stopAllPlayback()

        isSpotifyPlayback = true
        currentSpotifyPlaylistId = albumId
        currentSpotifyPlaylistName = albumName
        currentSpotifyImageUrl = imageUrl
        currentSpotifyTrackIndex = 0
        spotifyTracks = []

        GlobalState.shared.activeView = .song

        Task {
            let tracks = await SpotifyService.shared.fetchAlbumTracks(albumId: albumId)
            NSLog("[SongVM] playSpotifyAlbum got \(tracks.count) tracks for album=\(albumName)")
            await MainActor.run {
                // Set album image on all tracks since album tracks don't have it
                self.spotifyTracks = tracks.map { track in
                    SpotifyTrack(
                        id: track.id,
                        uri: track.uri,
                        name: track.name,
                        artist: track.artist,
                        album: albumName,
                        albumImageUrl: imageUrl,
                        durationMs: track.durationMs
                    )
                }
                if !self.spotifyTracks.isEmpty {
                    NSLog("[SongVM] playSpotifyAlbum starting first track uri=\(self.spotifyTracks[0].uri) name=\(self.spotifyTracks[0].name)")
                    self.waitForPlayerAndPlay(trackIndex: 0)
                } else {
                    NSLog("[SongVM] playSpotifyAlbum: no tracks fetched, nothing to play")
                }
            }
        }

        TelemetryDeck.signal("Spotify.playAlbum", parameters: ["albumName": albumName])
    }

    private func waitForPlayerAndPlay(trackIndex: Int) {
        if SpotifyService.shared.isPlayerReady {
            playSpotifyTrack(at: trackIndex)
        } else {
            // Wait for player ready and then play
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.waitForPlayerAndPlay(trackIndex: trackIndex)
            }
        }
    }

    func playSpotifyTrack(at index: Int) {
        guard index >= 0 && index < spotifyTracks.count else { return }
        currentSpotifyTrackIndex = index
        let track = spotifyTracks[index]
        SpotifyService.shared.play(uri: track.uri)
        isPlaying = true
        duration = TimeInterval(track.durationMs) / 1000
        currentTime = 0
        lastSpotifyPosition = 0
        startSpotifyTimer()
        updateNowPlayingInfo()
    }

    private func stopAllPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        streamPlayer?.pause()
        streamPlayer = nil
        isRadioStation = false
        isSpotifyPlayback = false
        isPlaying = false
        stopTimer()
        stopSpotifyTimer()
    }

    var currentSpotifyTrack: SpotifyTrack? {
        guard isSpotifyPlayback && currentSpotifyTrackIndex < spotifyTracks.count else { return nil }
        return spotifyTracks[currentSpotifyTrackIndex]
    }

    private var cachedSpotifyArtwork: (url: String, artwork: MPMediaItemArtwork)?

    func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()

        if isSpotifyPlayback {
            if let track = currentSpotifyTrack {
                nowPlayingInfo[MPMediaItemPropertyTitle] = track.name
                nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
                nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = track.album
                nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
                nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
                nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

                // Set album artwork
                if let imageUrl = track.albumImageUrl ?? currentSpotifyImageUrl {
                    if let cached = cachedSpotifyArtwork, cached.url == imageUrl {
                        nowPlayingInfo[MPMediaItemPropertyArtwork] = cached.artwork
                    } else {
                        loadSpotifyArtwork(from: imageUrl)
                    }
                }
            }
        } else if isRadioStation {
            nowPlayingInfo[MPMediaItemPropertyTitle] = currentRadioName
            nowPlayingInfo[MPMediaItemPropertyArtist] = "Live Radio"
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = 0.0
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0.0
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

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

    private func loadSpotifyArtwork(from urlString: String) {
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self,
                  let data = data,
                  let image = NSImage(data: data) else { return }

            DispatchQueue.main.async {
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                self.cachedSpotifyArtwork = (urlString, artwork)
                self.updateNowPlayingInfo()
            }
        }.resume()
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
        if isSpotifyPlayback {
            guard !spotifyTracks.isEmpty else { return }
            currentSpotifyTrackIndex = (currentSpotifyTrackIndex + 1) % spotifyTracks.count
            playSpotifyTrack(at: currentSpotifyTrackIndex)
            return
        }
        if isRadioStation { return }
        guard !songs.isEmpty else { return }
        currentSong = (currentSong + 1) % songs.count
        self.loadAudioFile(songs[currentSong].pathToAudioFile)
        self.playPauseClick()
    }

    func prevClick() {
        if isSpotifyPlayback {
            guard !spotifyTracks.isEmpty else { return }
            currentSpotifyTrackIndex = (currentSpotifyTrackIndex - 1 + spotifyTracks.count) % spotifyTracks.count
            playSpotifyTrack(at: currentSpotifyTrackIndex)
            return
        }
        if isRadioStation { return }
        guard !songs.isEmpty else { return }
        currentSong = (currentSong - 1 + songs.count) % songs.count
        self.loadAudioFile(songs[currentSong].pathToAudioFile)
        self.playPauseClick()
    }

    func playPauseClick() {
        if isSpotifyPlayback {
            SpotifyService.shared.togglePlayPause()
            return
        }
        if isRadioStation {
            if isPlaying {
                streamPlayer?.pause()
                isPlaying = false
                MPNowPlayingInfoCenter.default().playbackState = .paused
            } else {
                streamPlayer?.play()
                isPlaying = true
                MPNowPlayingInfoCenter.default().playbackState = .playing
            }
            return
        }
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
        if isSpotifyPlayback {
            let newPos = max(0, currentTime - 5)
            SpotifyService.shared.seek(positionMs: Int(newPos * 1000))
            currentTime = newPos
            hapticManager.perform(.generic, performanceTime: .now)
            return
        }
        if isRadioStation { return }
        guard let player = audioPlayer else { return }

        if currentTime > 0.0 {
            player.currentTime -= 5
            currentTime -= 5
            if currentTime < 0 { currentTime = 0 }
            hapticManager.perform(.generic, performanceTime: .now)
        }
    }

    func wheelDown() {
        if isSpotifyPlayback {
            let newPos = min(duration, currentTime + 5)
            SpotifyService.shared.seek(positionMs: Int(newPos * 1000))
            currentTime = newPos
            hapticManager.perform(.generic, performanceTime: .now)
            return
        }
        if isRadioStation { return }
        guard let player = audioPlayer else { return }

        if currentTime < duration {
            player.currentTime += 5
            currentTime += 5
            if currentTime > duration { currentTime = duration }
            hapticManager.perform(.generic, performanceTime: .now)
        }
    }

    func menuClick() {
        if isSpotifyPlayback && SpotifyService.shared.isPlaying {
            SpotifyService.shared.togglePlayPause()
        }
        stopAllPlayback()
        currentRadioName = ""
        currentSpotifyPlaylistId = ""
        currentSpotifyPlaylistName = ""
        spotifyTracks = []
        GlobalState.shared.activeView = .albums
    }
    
    deinit {
        stopTimer()
        stopSpotifyTimer()
        streamPlayer?.pause()
        streamPlayer = nil
        audioPlayer?.stop()
        audioPlayer = nil
    }
}
