//
//  SpotifySettings.swift
//  Pod
//

import SwiftUI

struct SpotifySettings: View {
    @StateObject private var spotifyService = SpotifyService.shared
    @State private var selectedSection = "account"

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 0) {
                SidebarButton(title: "Account", icon: "person.circle", isSelected: selectedSection == "account") {
                    selectedSection = "account"
                }
                if spotifyService.isConnected {
                    SidebarButton(title: "Playlists", icon: "music.note.list", isSelected: selectedSection == "playlists") {
                        selectedSection = "playlists"
                    }
                    SidebarButton(title: "Albums", icon: "square.stack", isSelected: selectedSection == "albums") {
                        selectedSection = "albums"
                    }
                }
                Spacer()
            }
            .frame(minWidth: 140, maxWidth: 180)
            .background(Color(NSColor.controlBackgroundColor))

            Group {
                switch selectedSection {
                case "playlists":
                    SpotifyPlaylistsView(spotifyService: spotifyService)
                case "albums":
                    SpotifyAlbumsView(spotifyService: spotifyService)
                default:
                    SpotifyAccountView(spotifyService: spotifyService)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SpotifyConnected"))) { _ in
            selectedSection = "playlists"
        }
    }
}

// MARK: - Account View

struct SpotifyAccountView: View {
    @ObservedObject var spotifyService: SpotifyService

    var body: some View {
        CenteredSettingsContent {
            if spotifyService.isConnected {
                connectedContent
            } else {
                disconnectedContent
            }
        }
    }

    private var connectedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)

            Text("Connected to Spotify")
                .font(.title2)
                .fontWeight(.bold)

            if let user = spotifyService.currentUser {
                userInfo(user)
            }

            if spotifyService.isPlayerReady {
                Label("Player ready", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            Button("Disconnect") {
                spotifyService.disconnect()
            }
            .buttonStyle(.bordered)
        }
    }

    private func userInfo(_ user: SpotifyUser) -> some View {
        VStack(spacing: 10) {
            Text(user.displayName ?? user.id)
                .font(.headline)

            if let email = user.email {
                Text(email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if user.isPremium {
                Label("Premium", systemImage: "star.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
            } else {
                premiumRequiredBadge
            }
        }
    }

    private var premiumRequiredBadge: some View {
        VStack(spacing: 6) {
            WarningBadge(text: "Premium Required", type: .error)
            Text("Playback won't work with a free account")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var disconnectedContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "music.note")
                .font(.system(size: 50))
                .foregroundColor(.green)

            Text("Spotify Integration")
                .font(.title2)
                .fontWeight(.bold)

            Text("Play your Spotify playlists directly in Pod using the click wheel.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 300)

            WarningBadge(text: "Spotify Premium required", type: .warning)

            Text("Spotify playback requires a Premium account.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 280)

            Button(action: { spotifyService.startAuth() }) {
                Label("Connect with Spotify", systemImage: "link")
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
    }
}

// MARK: - Playlists View

struct SpotifyPlaylistsView: View {
    @ObservedObject var spotifyService: SpotifyService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Select playlists to show in carousel")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            if spotifyService.allPlaylists.isEmpty {
                SettingsEmptyState(
                    icon: "arrow.clockwise",
                    title: "Loading...",
                    description: "Fetching your playlists"
                )
            } else {
                List {
                    ForEach(spotifyService.allPlaylists) { playlist in
                        SpotifyPlaylistRow(playlist: playlist, spotifyService: spotifyService)
                    }
                }
            }
        }
        .onAppear {
            if spotifyService.allPlaylists.isEmpty {
                Task { await spotifyService.fetchUserPlaylists() }
            }
        }
    }
}

// MARK: - Playlist Row

struct SpotifyPlaylistRow: View {
    let playlist: SpotifyPlaylist
    @ObservedObject var spotifyService: SpotifyService

    private var isSelected: Bool {
        spotifyService.isPlaylistSelected(playlist)
    }

    var body: some View {
        HStack(spacing: 12) {
            playlistImage
            playlistInfo
            Spacer()
            selectionButton
        }
        .padding(.vertical, 4)
    }

    private var playlistImage: some View {
        AsyncImage(url: URL(string: playlist.imageUrl ?? "")) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            default:
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(Image(systemName: "music.note").foregroundColor(.gray))
            }
        }
        .frame(width: 44, height: 44)
        .cornerRadius(6)
    }

    private var playlistInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(playlist.name)
                .font(.headline)
                .lineLimit(1)
            Text("\(playlist.trackCount) tracks")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var selectionButton: some View {
        Button(action: { spotifyService.togglePlaylistSelection(playlist) }) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(isSelected ? .green : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Albums View

struct SpotifyAlbumsView: View {
    @ObservedObject var spotifyService: SpotifyService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Select albums to show in carousel")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            if spotifyService.allAlbums.isEmpty {
                SettingsEmptyState(
                    icon: "arrow.clockwise",
                    title: "Loading...",
                    description: "Fetching your albums"
                )
            } else {
                List {
                    ForEach(spotifyService.allAlbums) { album in
                        SpotifyAlbumRow(album: album, spotifyService: spotifyService)
                    }
                }
            }
        }
        .onAppear {
            if spotifyService.allAlbums.isEmpty {
                Task { await spotifyService.fetchUserAlbums() }
            }
        }
    }
}

// MARK: - Album Row

struct SpotifyAlbumRow: View {
    let album: SpotifyAlbum
    @ObservedObject var spotifyService: SpotifyService

    private var isSelected: Bool {
        spotifyService.isAlbumSelected(album)
    }

    var body: some View {
        HStack(spacing: 12) {
            albumImage
            albumInfo
            Spacer()
            selectionButton
        }
        .padding(.vertical, 4)
    }

    private var albumImage: some View {
        AsyncImage(url: URL(string: album.imageUrl ?? "")) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            default:
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(Image(systemName: "music.note").foregroundColor(.gray))
            }
        }
        .frame(width: 44, height: 44)
        .cornerRadius(6)
    }

    private var albumInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(album.name)
                .font(.headline)
                .lineLimit(1)
            Text(album.artist)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    private var selectionButton: some View {
        Button(action: { spotifyService.toggleAlbumSelection(album) }) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(isSelected ? .green : .secondary)
        }
        .buttonStyle(.plain)
    }
}
