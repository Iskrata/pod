//
//  SpotifyService.swift
//  Pod
//
//  Created by Claude on 03.02.26.
//

import Foundation
import WebKit
import Combine
import AppKit
import CryptoKit

class SpotifyService: NSObject, ObservableObject {
    static let shared = SpotifyService()

    @Published var isConnected = false
    @Published var currentUser: SpotifyUser?
    @Published var isPlayerReady = false
    @Published var isPlaying = false
    @Published var currentTrackPosition: TimeInterval = 0
    @Published var currentTrackDuration: TimeInterval = 0
    @Published var currentTrackId: String?
    @Published var currentTrackName: String?
    @Published var currentTrackArtist: String?
    @Published var currentTrackAlbum: String?
    @Published var currentTrackImageUrl: String?
    @Published var selectedPlaylists: [SpotifyPlaylist] = []
    @Published var allPlaylists: [SpotifyPlaylist] = []
    @Published var selectedAlbums: [SpotifyAlbum] = []
    @Published var allAlbums: [SpotifyAlbum] = []

    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiration: Date?
    private var codeVerifier: String?

    var webView: WKWebView?

    private let userDefaultsTokenKey = "spotifyAccessToken"
    private let userDefaultsRefreshKey = "spotifyRefreshToken"
    private let userDefaultsExpirationKey = "spotifyTokenExpiration"
    private let userDefaultsSelectedPlaylistsKey = "spotifySelectedPlaylists"
    private let userDefaultsSelectedAlbumsKey = "spotifySelectedAlbums"

    private override init() {
        super.init()
        loadTokens()
        loadSelectedPlaylists()
        loadSelectedAlbums()
        if accessToken != nil {
            Task { await validateAndRefreshToken() }
        }
    }

    // MARK: - OAuth PKCE

    func startAuth() {
        codeVerifier = generateCodeVerifier()
        guard let verifier = codeVerifier else { return }
        let challenge = generateCodeChallenge(from: verifier)

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: SpotifyConstants.clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: SpotifyConstants.redirectUri),
            URLQueryItem(name: "scope", value: SpotifyConstants.scopes),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge)
        ]

        guard let url = components.url else { return }
        NSWorkspace.shared.open(url)
    }

    func handleCallback(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return
        }
        Task { await exchangeCodeForToken(code: code) }
    }

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func exchangeCodeForToken(code: String) async {
        guard let verifier = codeVerifier else { return }

        let url = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": SpotifyConstants.redirectUri,
            "client_id": SpotifyConstants.clientId,
            "code_verifier": verifier
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&").data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
            await handleTokenResponse(tokenResponse)
        } catch {
            print("Token exchange failed: \(error)")
        }
    }

    @MainActor
    private func handleTokenResponse(_ response: SpotifyTokenResponse) {
        accessToken = response.accessToken
        if let refresh = response.refreshToken {
            refreshToken = refresh
        }
        tokenExpiration = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        saveTokens()

        Task {
            await fetchUserProfile()
            await fetchUserPlaylists()
            await fetchUserAlbums()
            setupWebView()
            NotificationCenter.default.post(name: NSNotification.Name("SpotifyConnected"), object: nil)
        }
    }

    private func validateAndRefreshToken() async {
        guard let expiration = tokenExpiration else {
            await MainActor.run { disconnect() }
            return
        }

        if Date() >= expiration.addingTimeInterval(-60) {
            await refreshAccessToken()
        } else {
            await MainActor.run {
                isConnected = true
            }
            await fetchUserProfile()
            await fetchUserPlaylists()
            await fetchUserAlbums()
            await MainActor.run { setupWebView() }
        }
    }

    private func refreshAccessToken() async {
        guard let refresh = refreshToken else {
            await MainActor.run { disconnect() }
            return
        }

        let url = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type": "refresh_token",
            "refresh_token": refresh,
            "client_id": SpotifyConstants.clientId
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
            await handleTokenResponse(tokenResponse)
        } catch {
            print("Token refresh failed: \(error)")
            await MainActor.run { disconnect() }
        }
    }

    // MARK: - Token Storage

    private func saveTokens() {
        UserDefaults.standard.set(accessToken, forKey: userDefaultsTokenKey)
        UserDefaults.standard.set(refreshToken, forKey: userDefaultsRefreshKey)
        UserDefaults.standard.set(tokenExpiration, forKey: userDefaultsExpirationKey)
    }

    private func loadTokens() {
        accessToken = UserDefaults.standard.string(forKey: userDefaultsTokenKey)
        refreshToken = UserDefaults.standard.string(forKey: userDefaultsRefreshKey)
        tokenExpiration = UserDefaults.standard.object(forKey: userDefaultsExpirationKey) as? Date
        isConnected = accessToken != nil
    }

    func disconnect() {
        accessToken = nil
        refreshToken = nil
        tokenExpiration = nil
        currentUser = nil
        isConnected = false
        isPlayerReady = false
        selectedPlaylists = []
        allPlaylists = []
        selectedAlbums = []
        allAlbums = []
        webView?.stopLoading()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "spotifyBridge")
        webView = nil
        webViewWindow?.close()
        webViewWindow = nil

        UserDefaults.standard.removeObject(forKey: userDefaultsTokenKey)
        UserDefaults.standard.removeObject(forKey: userDefaultsRefreshKey)
        UserDefaults.standard.removeObject(forKey: userDefaultsExpirationKey)
        UserDefaults.standard.removeObject(forKey: userDefaultsSelectedPlaylistsKey)
        UserDefaults.standard.removeObject(forKey: userDefaultsSelectedAlbumsKey)

        NotificationCenter.default.post(name: NSNotification.Name("SpotifyPlaylistsChanged"), object: nil)
    }

    // MARK: - API Calls

    private func fetchUserProfile() async {
        guard let token = accessToken else { return }

        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let user = try JSONDecoder().decode(SpotifyUser.self, from: data)
            await MainActor.run {
                self.currentUser = user
                self.isConnected = true
            }
        } catch {
            print("Failed to fetch user profile: \(error)")
        }
    }

    func fetchUserPlaylists() async {
        guard let token = accessToken else { return }

        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/playlists?limit=50")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(SpotifyPlaylistsResponse.self, from: data)
            await MainActor.run {
                self.allPlaylists = response.items
            }
        } catch {
            print("Failed to fetch playlists: \(error)")
        }
    }

    func fetchUserAlbums() async {
        guard let token = accessToken else { return }

        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/albums?limit=50")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(SpotifyAlbumsResponse.self, from: data)
            await MainActor.run {
                self.allAlbums = response.items
            }
        } catch {
            print("Failed to fetch albums: \(error)")
        }
    }

    func fetchAlbumTracks(albumId: String) async -> [SpotifyTrack] {
        guard let token = accessToken else { return [] }

        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/albums/\(albumId)/tracks?limit=50")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(SpotifyAlbumTracksResponse.self, from: data)
            return response.items
        } catch {
            print("Failed to fetch album tracks: \(error)")
            return []
        }
    }

    func fetchPlaylistTracks(playlistId: String) async -> [SpotifyTrack] {
        guard let token = accessToken else { return [] }

        var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/playlists/\(playlistId)/tracks?limit=100")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(SpotifyTracksResponse.self, from: data)
            return response.items
        } catch {
            print("Failed to fetch tracks: \(error)")
            return []
        }
    }

    // MARK: - Selected Playlists

    func togglePlaylistSelection(_ playlist: SpotifyPlaylist) {
        if selectedPlaylists.contains(where: { $0.id == playlist.id }) {
            selectedPlaylists.removeAll { $0.id == playlist.id }
        } else {
            selectedPlaylists.append(playlist)
        }
        saveSelectedPlaylists()
        NotificationCenter.default.post(name: NSNotification.Name("SpotifyPlaylistsChanged"), object: nil)
    }

    func isPlaylistSelected(_ playlist: SpotifyPlaylist) -> Bool {
        selectedPlaylists.contains { $0.id == playlist.id }
    }

    private func saveSelectedPlaylists() {
        if let encoded = try? JSONEncoder().encode(selectedPlaylists) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsSelectedPlaylistsKey)
        }
    }

    private func loadSelectedPlaylists() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsSelectedPlaylistsKey),
           let decoded = try? JSONDecoder().decode([SpotifyPlaylist].self, from: data) {
            selectedPlaylists = decoded
        }
    }

    // MARK: - Selected Albums

    func toggleAlbumSelection(_ album: SpotifyAlbum) {
        if selectedAlbums.contains(where: { $0.id == album.id }) {
            selectedAlbums.removeAll { $0.id == album.id }
        } else {
            selectedAlbums.append(album)
        }
        saveSelectedAlbums()
        NotificationCenter.default.post(name: NSNotification.Name("SpotifyPlaylistsChanged"), object: nil)
    }

    func isAlbumSelected(_ album: SpotifyAlbum) -> Bool {
        selectedAlbums.contains { $0.id == album.id }
    }

    private func saveSelectedAlbums() {
        if let encoded = try? JSONEncoder().encode(selectedAlbums) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsSelectedAlbumsKey)
        }
    }

    private func loadSelectedAlbums() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsSelectedAlbumsKey),
           let decoded = try? JSONDecoder().decode([SpotifyAlbum].self, from: data) {
            selectedAlbums = decoded
        }
    }

    // MARK: - Web Playback SDK

    private var webViewWindow: NSWindow?

    func setupWebView() {
        guard webView == nil else { return }

        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.mediaTypesRequiringUserActionForPlayback = []

        let contentController = WKUserContentController()
        contentController.add(self, name: "spotifyBridge")
        config.userContentController = contentController

        let wv = WKWebView(frame: NSRect(x: 0, y: 0, width: 1, height: 1), configuration: config)
        wv.navigationDelegate = self
        webView = wv

        // WebView needs to be in a window for audio playback
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        window.contentView = wv
        window.orderOut(nil)
        webViewWindow = window

        guard let htmlPath = Bundle.main.path(forResource: "spotify-player", ofType: "html"),
              let htmlContent = try? String(contentsOfFile: htmlPath, encoding: .utf8) else {
            print("Failed to load spotify-player.html")
            return
        }

        let htmlWithToken = htmlContent.replacingOccurrences(of: "{{ACCESS_TOKEN}}", with: accessToken ?? "")
        wv.loadHTMLString(htmlWithToken, baseURL: nil)
    }

    // MARK: - Playback Controls

    func play(uri: String) {
        let js = "playTrack('\(uri)')"
        webView?.evaluateJavaScript(js) { _, error in
            if let error = error {
                print("Play error: \(error)")
            }
        }
    }

    func playTrackInContext(contextUri: String, trackIndex: Int) {
        let js = "playContext('\(contextUri)', \(trackIndex))"
        webView?.evaluateJavaScript(js) { _, error in
            if let error = error {
                print("Play context error: \(error)")
            }
        }
    }

    func togglePlayPause() {
        let js = "togglePlayPause()"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    func nextTrack() {
        let js = "nextTrack()"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    func previousTrack() {
        let js = "previousTrack()"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    func seek(positionMs: Int) {
        let js = "seek(\(positionMs))"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    func setVolume(_ volume: Float) {
        let js = "setVolume(\(volume))"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

}

// MARK: - WKScriptMessageHandler

extension SpotifyService: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any],
              let event = dict["event"] as? String else { return }

        DispatchQueue.main.async {
            switch event {
            case "ready":
                self.isPlayerReady = true
                print("Spotify player ready")

            case "not_ready":
                self.isPlayerReady = false

            case "state_changed":
                if let paused = dict["paused"] as? Bool {
                    self.isPlaying = !paused
                }
                if let position = dict["position"] as? Int {
                    self.currentTrackPosition = TimeInterval(position) / 1000
                }
                if let duration = dict["duration"] as? Int {
                    self.currentTrackDuration = TimeInterval(duration) / 1000
                }
                // Track info
                self.currentTrackId = dict["trackId"] as? String
                self.currentTrackName = dict["trackName"] as? String
                self.currentTrackArtist = dict["trackArtist"] as? String
                self.currentTrackAlbum = dict["trackAlbum"] as? String
                self.currentTrackImageUrl = dict["trackImage"] as? String

                let trackChanged = dict["trackChanged"] as? Bool ?? false
                NotificationCenter.default.post(
                    name: NSNotification.Name("SpotifyStateChanged"),
                    object: nil,
                    userInfo: ["trackChanged": trackChanged]
                )

            case "position_update":
                if let position = dict["position"] as? Int {
                    self.currentTrackPosition = TimeInterval(position) / 1000
                }
                if let duration = dict["duration"] as? Int {
                    self.currentTrackDuration = TimeInterval(duration) / 1000
                }
                NotificationCenter.default.post(name: NSNotification.Name("SpotifyStateChanged"), object: nil)

            case "error":
                print("Spotify error: \(dict["message"] ?? "unknown")")

            default:
                break
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension SpotifyService: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("WebView finished loading")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("WebView failed: \(error)")
    }
}
