import Foundation
import Combine
import AppKit

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

    private let bridge = SpotifyBridge.shared

    private let userDefaultsCredentialsKey = "spotifyBridgeCredentials"
    private let userDefaultsSelectedPlaylistsKey = "spotifySelectedPlaylists"
    private let userDefaultsSelectedAlbumsKey = "spotifySelectedAlbums"

    private override init() {
        super.init()
        loadSelectedPlaylists()
        loadSelectedAlbums()
        setupBridgeEvents()

        // If we have stored credentials, try to reconnect
        if let creds = loadCredentials() {
            startBridgeWithCredentials(creds)
        }
    }

    // MARK: - Bridge Events

    private func setupBridgeEvents() {
        bridge.onEvent = { [weak self] event, data in
            guard let self = self else { return }

            switch event {
            case "auth_complete":
                self.isConnected = true
                self.isPlayerReady = true
                Task {
                    await self.fetchUserPlaylists()
                    await self.fetchUserAlbums()
                }
                NotificationCenter.default.post(name: NSNotification.Name("SpotifyConnected"), object: nil)

            case "player_state":
                let wasPlaying = self.isPlaying
                let oldTrackUri = self.currentTrackId

                self.isPlaying = data["is_playing"] as? Bool ?? false

                if let pos = data["position_ms"] as? Int {
                    self.currentTrackPosition = TimeInterval(pos) / 1000
                }

                let trackUri = data["track_uri"] as? String
                let trackChanged = trackUri != oldTrackUri && trackUri != nil

                if trackChanged, let uri = trackUri {
                    self.currentTrackId = uri
                    // Track metadata will be filled by the caller who loaded the tracks
                }

                NotificationCenter.default.post(
                    name: NSNotification.Name("SpotifyStateChanged"),
                    object: nil,
                    userInfo: ["trackChanged": trackChanged]
                )

            case "track_end":
                NotificationCenter.default.post(
                    name: NSNotification.Name("SpotifyStateChanged"),
                    object: nil,
                    userInfo: ["trackChanged": true, "trackEnded": true]
                )

            case "session_expired":
                print("[SpotifyService] Session expired, attempting re-auth")
                if let creds = self.loadCredentials() {
                    self.startBridgeWithCredentials(creds)
                } else {
                    self.disconnect()
                }

            default:
                break
            }
        }
    }

    // MARK: - Auth

    func startAuth() {
        print("[SpotifyService] startAuth called, bridge.isRunning=\(bridge.isRunning)")
        bridge.start()
        print("[SpotifyService] bridge.start() done, isRunning=\(bridge.isRunning)")
        bridge.send(method: "auth_start") { [weak self] result in
            print("[SpotifyService] auth_start result: \(result)")
            switch result {
            case .success(let response):
                if let dict = response as? [String: Any],
                   let creds = dict["credentials"] {
                    // Store credentials for reconnection
                    if let credsData = try? JSONSerialization.data(withJSONObject: creds) {
                        UserDefaults.standard.set(credsData, forKey: self?.userDefaultsCredentialsKey ?? "")
                    }
                }
            case .failure(let error):
                print("[SpotifyService] Auth failed: \(error)")
            }
        }
    }

    private func startBridgeWithCredentials(_ creds: [String: Any]) {
        bridge.start()
        bridge.send(method: "auth_stored", params: ["credentials": creds]) { [weak self] result in
            if case .failure(let error) = result {
                print("[SpotifyService] Stored auth failed: \(error)")
                self?.disconnect()
            }
        }
    }

    private func loadCredentials() -> [String: Any]? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsCredentialsKey),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }

    func disconnect() {
        bridge.send(method: "disconnect")
        bridge.stop()

        currentUser = nil
        isConnected = false
        isPlayerReady = false
        isPlaying = false
        selectedPlaylists = []
        allPlaylists = []
        selectedAlbums = []
        allAlbums = []

        UserDefaults.standard.removeObject(forKey: userDefaultsCredentialsKey)
        UserDefaults.standard.removeObject(forKey: userDefaultsSelectedPlaylistsKey)
        UserDefaults.standard.removeObject(forKey: userDefaultsSelectedAlbumsKey)

        NotificationCenter.default.post(name: NSNotification.Name("SpotifyPlaylistsChanged"), object: nil)
    }

    // MARK: - API Calls

    func fetchUserPlaylists() async {
        do {
            let result = try await bridge.send(method: "get_playlists")
            guard let dict = result as? [String: Any],
                  let items = dict["playlists"] as? [[String: Any]] else { return }

            let playlists = items.compactMap { item -> SpotifyPlaylist? in
                guard let id = item["id"] as? String,
                      let name = item["name"] as? String else { return nil }
                return SpotifyPlaylist(
                    id: id,
                    name: name,
                    imageUrl: item["imageUrl"] as? String,
                    trackCount: item["trackCount"] as? Int ?? 0
                )
            }

            await MainActor.run {
                self.allPlaylists = playlists
                if self.selectedPlaylists.isEmpty {
                    self.selectedPlaylists = playlists
                    self.saveSelectedPlaylists()
                    NotificationCenter.default.post(name: NSNotification.Name("SpotifyPlaylistsChanged"), object: nil)
                }
            }
        } catch {
            print("[SpotifyService] Failed to fetch playlists: \(error)")
        }
    }

    func fetchUserAlbums() async {
        do {
            let result = try await bridge.send(method: "get_saved_albums")
            guard let dict = result as? [String: Any],
                  let items = dict["albums"] as? [[String: Any]] else { return }

            let albums = items.compactMap { item -> SpotifyAlbum? in
                guard let id = item["id"] as? String,
                      let name = item["name"] as? String else { return nil }
                return SpotifyAlbum(
                    id: id,
                    name: name,
                    artist: item["artist"] as? String ?? "Unknown Artist",
                    imageUrl: item["imageUrl"] as? String,
                    trackCount: item["trackCount"] as? Int ?? 0,
                    uri: item["uri"] as? String ?? "spotify:album:\(id)"
                )
            }

            await MainActor.run {
                self.allAlbums = albums
                if self.selectedAlbums.isEmpty {
                    self.selectedAlbums = albums
                    self.saveSelectedAlbums()
                    NotificationCenter.default.post(name: NSNotification.Name("SpotifyPlaylistsChanged"), object: nil)
                }
            }
        } catch {
            print("[SpotifyService] Failed to fetch albums: \(error)")
        }
    }

    func fetchAlbumTracks(albumId: String) async -> [SpotifyTrack] {
        do {
            let result = try await bridge.send(method: "get_album_tracks", params: ["album_id": albumId])
            guard let dict = result as? [String: Any],
                  let items = dict["tracks"] as? [[String: Any]] else { return [] }
            return parseTracksFromBridge(items)
        } catch {
            print("[SpotifyService] Failed to fetch album tracks: \(error)")
            return []
        }
    }

    func fetchPlaylistTracks(playlistId: String) async -> [SpotifyTrack] {
        do {
            let result = try await bridge.send(method: "get_playlist_tracks", params: ["playlist_id": playlistId])
            guard let dict = result as? [String: Any],
                  let items = dict["tracks"] as? [[String: Any]] else { return [] }
            return parseTracksFromBridge(items)
        } catch {
            print("[SpotifyService] Failed to fetch playlist tracks: \(error)")
            return []
        }
    }

    private func parseTracksFromBridge(_ items: [[String: Any]]) -> [SpotifyTrack] {
        items.compactMap { item in
            guard let id = item["id"] as? String,
                  let uri = item["uri"] as? String,
                  let name = item["name"] as? String else { return nil }
            return SpotifyTrack(
                id: id,
                uri: uri,
                name: name,
                artist: item["artist"] as? String ?? "Unknown Artist",
                album: item["album"] as? String ?? "",
                albumImageUrl: item["albumImageUrl"] as? String,
                durationMs: item["durationMs"] as? Int ?? 0
            )
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

    // MARK: - Playback Controls

    func play(uri: String) {
        bridge.send(method: "play", params: ["uri": uri])
    }

    func playTrackInContext(contextUri: String, trackIndex: Int) {
        bridge.send(method: "play_context", params: ["context_uri": contextUri, "offset": trackIndex])
    }

    func togglePlayPause() {
        if isPlaying {
            bridge.send(method: "pause")
        } else {
            bridge.send(method: "resume")
        }
    }

    func nextTrack() {
        // Handled by SongViewModel via SpotifyPlaybackProvider
    }

    func previousTrack() {
        // Handled by SongViewModel via SpotifyPlaybackProvider
    }

    func seek(positionMs: Int) {
        bridge.send(method: "seek", params: ["position_ms": positionMs])
    }

    func setVolume(_ volume: Float) {
        bridge.send(method: "set_volume", params: ["volume": volume])
    }
}
