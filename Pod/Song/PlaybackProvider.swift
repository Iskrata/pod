//
//  PlaybackProvider.swift
//  Pod
//

import Foundation
import AVFoundation
import MediaPlayer
import AppKit

// MARK: - Protocol

protocol PlaybackProvider: AnyObject {
    var isPlaying: Bool { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var title: String { get }
    var artist: String? { get }
    var album: String? { get }
    var artworkImage: NSImage? { get }
    var artworkUrl: String? { get }

    func play()
    func pause()
    func togglePlayPause()
    func seekForward(_ seconds: TimeInterval)
    func seekBackward(_ seconds: TimeInterval)
    func nextTrack() -> Bool
    func previousTrack() -> Bool
    func stop()
}

// MARK: - Local Playback

class LocalPlaybackProvider: PlaybackProvider {
    private var audioPlayer: AVAudioPlayer?
    private var songs: [Song] = []
    private var currentIndex: Int = 0
    private var timer: Timer?

    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    var duration: TimeInterval { audioPlayer?.duration ?? 0 }

    var title: String { songs.isEmpty ? "" : songs[currentIndex].title }
    var artist: String? { songs.isEmpty ? nil : songs[currentIndex].artist }
    var album: String? { songs.isEmpty ? nil : songs[currentIndex].album }
    var artworkImage: NSImage? { songs.isEmpty ? nil : songs[currentIndex].coverImage }
    var artworkUrl: String? { nil }

    var onTimeUpdate: ((TimeInterval) -> Void)?
    var onTrackEnd: (() -> Void)?

    func load(songs: [Song], startIndex: Int = 0) {
        self.songs = songs
        self.currentIndex = startIndex
        guard !songs.isEmpty else { return }
        loadCurrentTrack()
    }

    private func loadCurrentTrack() {
        guard currentIndex < songs.count else { return }
        let path = songs[currentIndex].pathToAudioFile
        do {
            let url = URL(fileURLWithPath: path)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = 0.6
            currentTime = 0
        } catch {
            print("Failed to load audio: \(error)")
        }
    }

    func play() {
        audioPlayer?.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func seekForward(_ seconds: TimeInterval) {
        guard let player = audioPlayer else { return }
        player.currentTime = min(player.currentTime + seconds, duration)
        currentTime = player.currentTime
    }

    func seekBackward(_ seconds: TimeInterval) {
        guard let player = audioPlayer else { return }
        player.currentTime = max(player.currentTime - seconds, 0)
        currentTime = player.currentTime
    }

    func nextTrack() -> Bool {
        guard !songs.isEmpty else { return false }
        currentIndex = (currentIndex + 1) % songs.count
        loadCurrentTrack()
        if isPlaying { play() }
        return true
    }

    func previousTrack() -> Bool {
        guard !songs.isEmpty else { return false }
        currentIndex = (currentIndex - 1 + songs.count) % songs.count
        loadCurrentTrack()
        if isPlaying { play() }
        return true
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        stopTimer()
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
            self.onTimeUpdate?(self.currentTime)

            if player.currentTime >= player.duration - 0.5 {
                self.onTrackEnd?()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stop()
    }
}

// MARK: - Radio Playback

class RadioPlaybackProvider: PlaybackProvider {
    private var streamPlayer: AVPlayer?
    private var stationName: String = ""
    private var stationUrl: String = ""

    private(set) var isPlaying = false
    var currentTime: TimeInterval { 0 }
    var duration: TimeInterval { 0 }

    var title: String { stationName }
    var artist: String? { "Live Radio" }
    var album: String? { nil }
    var artworkImage: NSImage? { NSImage(systemSymbolName: "radio", accessibilityDescription: nil) }
    var artworkUrl: String? { nil }

    func load(url: String, name: String) {
        stationUrl = url
        stationName = name

        guard let streamURL = URL(string: url) else { return }
        let playerItem = AVPlayerItem(url: streamURL)
        streamPlayer = AVPlayer(playerItem: playerItem)
    }

    func play() {
        streamPlayer?.play()
        isPlaying = true
    }

    func pause() {
        streamPlayer?.pause()
        isPlaying = false
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func seekForward(_ seconds: TimeInterval) {}
    func seekBackward(_ seconds: TimeInterval) {}
    func nextTrack() -> Bool { false }
    func previousTrack() -> Bool { false }

    func stop() {
        streamPlayer?.pause()
        streamPlayer = nil
        isPlaying = false
    }

    deinit {
        stop()
    }
}

// MARK: - Spotify Playback

class SpotifyPlaybackProvider: PlaybackProvider {
    private var tracks: [SpotifyTrack] = []
    private var currentIndex: Int = 0
    private var playlistName: String = ""
    private var playlistImageUrl: String?

    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    var title: String { currentTrack?.name ?? playlistName }
    var artist: String? { currentTrack?.artist ?? "Spotify" }
    var album: String? { currentTrack?.album }
    var artworkImage: NSImage? { nil }
    var artworkUrl: String? { currentTrack?.albumImageUrl ?? playlistImageUrl }

    var currentTrack: SpotifyTrack? {
        guard currentIndex < tracks.count else { return nil }
        return tracks[currentIndex]
    }

    var onStateChange: (() -> Void)?

    init() {
        setupObserver()
    }

    private func setupObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(spotifyStateChanged(_:)),
            name: NSNotification.Name("SpotifyStateChanged"),
            object: nil
        )
    }

    @objc private func spotifyStateChanged(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let service = SpotifyService.shared
            self.isPlaying = service.isPlaying
            self.currentTime = service.currentTrackPosition
            self.duration = service.currentTrackDuration

            // Track change detection
            if let userInfo = notification.userInfo,
               let trackChanged = userInfo["trackChanged"] as? Bool,
               trackChanged,
               let currentTrackId = service.currentTrackId {
                if let index = self.tracks.firstIndex(where: { $0.id == currentTrackId }) {
                    self.currentIndex = index
                }
            }

            self.onStateChange?()
        }
    }

    func load(tracks: [SpotifyTrack], playlistName: String, imageUrl: String?) {
        self.tracks = tracks
        self.playlistName = playlistName
        self.playlistImageUrl = imageUrl
        self.currentIndex = 0
    }

    func playTrack(at index: Int) {
        guard index >= 0 && index < tracks.count else { return }
        currentIndex = index
        let track = tracks[index]
        SpotifyService.shared.play(uri: track.uri)
        isPlaying = true
        duration = TimeInterval(track.durationMs) / 1000
        currentTime = 0
    }

    func play() {
        SpotifyService.shared.togglePlayPause()
    }

    func pause() {
        SpotifyService.shared.togglePlayPause()
    }

    func togglePlayPause() {
        SpotifyService.shared.togglePlayPause()
    }

    func seekForward(_ seconds: TimeInterval) {
        let newPos = min(duration, currentTime + seconds)
        SpotifyService.shared.seek(positionMs: Int(newPos * 1000))
        currentTime = newPos
    }

    func seekBackward(_ seconds: TimeInterval) {
        let newPos = max(0, currentTime - seconds)
        SpotifyService.shared.seek(positionMs: Int(newPos * 1000))
        currentTime = newPos
    }

    func nextTrack() -> Bool {
        guard !tracks.isEmpty else { return false }
        currentIndex = (currentIndex + 1) % tracks.count
        playTrack(at: currentIndex)
        return true
    }

    func previousTrack() -> Bool {
        guard !tracks.isEmpty else { return false }
        currentIndex = (currentIndex - 1 + tracks.count) % tracks.count
        playTrack(at: currentIndex)
        return true
    }

    func stop() {
        if isPlaying {
            SpotifyService.shared.togglePlayPause()
        }
        tracks = []
        isPlaying = false
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
