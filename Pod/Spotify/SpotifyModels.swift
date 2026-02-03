//
//  SpotifyModels.swift
//  Pod
//
//  Created by Claude on 03.02.26.
//

import Foundation

struct SpotifyConstants {
    static let clientId = "3d495ad1d9e344e09ab66917db09cb7e"
    static let clientSecret = "794f97ad12a94e55bc7bb42b30aa9ce2"
    static let redirectUri = "pod://callback"
    static let scopes = [
        "streaming",
        "user-read-email",
        "user-read-private",
        "playlist-read-private",
        "playlist-read-collaborative",
        "user-library-read"
    ].joined(separator: " ")
}

struct SpotifyPlaylist: Codable, Identifiable {
    let id: String
    let name: String
    let imageUrl: String?
    let trackCount: Int

    // For decoding from Spotify API
    enum APICodingKeys: String, CodingKey {
        case id, name, images, tracks
    }

    // For encoding/decoding to UserDefaults
    enum StorageCodingKeys: String, CodingKey {
        case id, name, imageUrl, trackCount
    }

    init(from decoder: Decoder) throws {
        // Try storage format first (from UserDefaults)
        if let container = try? decoder.container(keyedBy: StorageCodingKeys.self),
           container.contains(.imageUrl) {
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
            trackCount = try container.decodeIfPresent(Int.self, forKey: .trackCount) ?? 0
        } else {
            // Decode from Spotify API format
            let container = try decoder.container(keyedBy: APICodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)

            let images = try container.decodeIfPresent([SpotifyImage].self, forKey: .images)
            imageUrl = images?.first?.url

            let tracksInfo = try container.decodeIfPresent(TracksInfo.self, forKey: .tracks)
            trackCount = tracksInfo?.total ?? 0
        }
    }

    init(id: String, name: String, imageUrl: String?, trackCount: Int) {
        self.id = id
        self.name = name
        self.imageUrl = imageUrl
        self.trackCount = trackCount
    }

    func encode(to encoder: Encoder) throws {
        // Always encode in storage format
        var container = encoder.container(keyedBy: StorageCodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encode(trackCount, forKey: .trackCount)
    }

    private struct TracksInfo: Codable {
        let total: Int
    }
}

// MARK: - Spotify Album

struct SpotifyAlbum: Codable, Identifiable {
    let id: String
    let name: String
    let artist: String
    let imageUrl: String?
    let trackCount: Int
    let uri: String

    // For Spotify API response (nested under "album")
    enum APICodingKeys: String, CodingKey {
        case album
    }

    enum AlbumKeys: String, CodingKey {
        case id, name, images, artists, uri
        case total_tracks
    }

    // For UserDefaults storage
    enum StorageCodingKeys: String, CodingKey {
        case id, name, artist, imageUrl, trackCount, uri
    }

    init(from decoder: Decoder) throws {
        // Try storage format first
        if let container = try? decoder.container(keyedBy: StorageCodingKeys.self),
           container.contains(.artist) {
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            artist = try container.decode(String.self, forKey: .artist)
            imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
            trackCount = try container.decodeIfPresent(Int.self, forKey: .trackCount) ?? 0
            uri = try container.decode(String.self, forKey: .uri)
        } else {
            // Decode from Spotify API format
            let container = try decoder.container(keyedBy: APICodingKeys.self)
            let albumContainer = try container.nestedContainer(keyedBy: AlbumKeys.self, forKey: .album)

            id = try albumContainer.decode(String.self, forKey: .id)
            name = try albumContainer.decode(String.self, forKey: .name)
            uri = try albumContainer.decode(String.self, forKey: .uri)
            trackCount = try albumContainer.decodeIfPresent(Int.self, forKey: .total_tracks) ?? 0

            let images = try albumContainer.decodeIfPresent([SpotifyImage].self, forKey: .images)
            imageUrl = images?.first?.url

            let artists = try albumContainer.decodeIfPresent([SpotifyArtist].self, forKey: .artists)
            artist = artists?.first?.name ?? "Unknown Artist"
        }
    }

    init(id: String, name: String, artist: String, imageUrl: String?, trackCount: Int, uri: String) {
        self.id = id
        self.name = name
        self.artist = artist
        self.imageUrl = imageUrl
        self.trackCount = trackCount
        self.uri = uri
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StorageCodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(artist, forKey: .artist)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encode(trackCount, forKey: .trackCount)
        try container.encode(uri, forKey: .uri)
    }
}

struct SpotifyAlbumsResponse: Codable {
    let items: [SpotifyAlbum]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Check if items exists - might be error response
        guard container.contains(.items) else {
            items = []
            return
        }

        var itemsContainer = try container.nestedUnkeyedContainer(forKey: .items)
        var albums: [SpotifyAlbum] = []
        while !itemsContainer.isAtEnd {
            if let album = try? itemsContainer.decode(SpotifyAlbum.self) {
                albums.append(album)
            } else {
                _ = try? itemsContainer.decode(AnyCodable.self)
            }
        }
        items = albums
    }

    private enum CodingKeys: String, CodingKey {
        case items
    }
}

struct SpotifyImage: Codable {
    let url: String
    let height: Int?
    let width: Int?
}

struct SpotifyTrack: Codable, Identifiable {
    let id: String
    let uri: String
    let name: String
    let artist: String
    let album: String
    let albumImageUrl: String?
    let durationMs: Int

    enum CodingKeys: String, CodingKey {
        case track
    }

    enum TrackKeys: String, CodingKey {
        case id, uri, name, artists, album, duration_ms
    }

    enum AlbumKeys: String, CodingKey {
        case name, images
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle null track (e.g., local files, unavailable tracks)
        guard container.contains(.track) else {
            throw DecodingError.keyNotFound(CodingKeys.track, .init(codingPath: [], debugDescription: "Track is null"))
        }

        // Check if track is null
        if try container.decodeNil(forKey: .track) {
            throw DecodingError.valueNotFound(String.self, .init(codingPath: [CodingKeys.track], debugDescription: "Track is null"))
        }

        let trackContainer = try container.nestedContainer(keyedBy: TrackKeys.self, forKey: .track)

        // Handle null id (some tracks have null id)
        guard let trackId = try trackContainer.decodeIfPresent(String.self, forKey: .id) else {
            throw DecodingError.valueNotFound(String.self, .init(codingPath: [TrackKeys.id], debugDescription: "Track id is null"))
        }
        id = trackId

        uri = try trackContainer.decode(String.self, forKey: .uri)
        name = try trackContainer.decode(String.self, forKey: .name)
        durationMs = try trackContainer.decode(Int.self, forKey: .duration_ms)

        let artists = try trackContainer.decode([SpotifyArtist].self, forKey: .artists)
        artist = artists.first?.name ?? "Unknown Artist"

        let albumContainer = try trackContainer.nestedContainer(keyedBy: AlbumKeys.self, forKey: .album)
        album = try albumContainer.decode(String.self, forKey: .name)
        let images = try albumContainer.decodeIfPresent([SpotifyImage].self, forKey: .images)
        albumImageUrl = images?.first?.url
    }

    init(id: String, uri: String, name: String, artist: String, album: String, albumImageUrl: String?, durationMs: Int) {
        self.id = id
        self.uri = uri
        self.name = name
        self.artist = artist
        self.album = album
        self.albumImageUrl = albumImageUrl
        self.durationMs = durationMs
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }
}

struct SpotifyArtist: Codable {
    let name: String
}

struct SpotifyPlaylistsResponse: Codable {
    let items: [SpotifyPlaylist]
}

struct SpotifyTracksResponse: Codable {
    let items: [SpotifyTrack]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var itemsContainer = try container.nestedUnkeyedContainer(forKey: .items)

        var tracks: [SpotifyTrack] = []
        while !itemsContainer.isAtEnd {
            if let track = try? itemsContainer.decode(SpotifyTrack.self) {
                tracks.append(track)
            } else {
                // Skip invalid/null tracks
                _ = try? itemsContainer.decode(AnyCodable.self)
            }
        }
        items = tracks
    }

    private enum CodingKeys: String, CodingKey {
        case items
    }
}

private struct AnyCodable: Codable {}

// Album tracks have a different structure (no "track" wrapper)
struct SpotifyAlbumTrack: Decodable, Identifiable {
    let id: String
    let uri: String
    let name: String
    let artist: String
    let durationMs: Int

    enum CodingKeys: String, CodingKey {
        case id, uri, name, artists, duration_ms
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        guard let trackId = try container.decodeIfPresent(String.self, forKey: .id) else {
            throw DecodingError.valueNotFound(String.self, .init(codingPath: [CodingKeys.id], debugDescription: "Track id is null"))
        }
        id = trackId
        uri = try container.decode(String.self, forKey: .uri)
        name = try container.decode(String.self, forKey: .name)
        durationMs = try container.decode(Int.self, forKey: .duration_ms)

        let artists = try container.decode([SpotifyArtist].self, forKey: .artists)
        artist = artists.first?.name ?? "Unknown Artist"
    }
}

struct SpotifyAlbumTracksResponse: Codable {
    let items: [SpotifyTrack]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var itemsContainer = try container.nestedUnkeyedContainer(forKey: .items)

        var tracks: [SpotifyTrack] = []
        while !itemsContainer.isAtEnd {
            if let albumTrack = try? itemsContainer.decode(SpotifyAlbumTrack.self) {
                // Convert album track to SpotifyTrack
                let track = SpotifyTrack(
                    id: albumTrack.id,
                    uri: albumTrack.uri,
                    name: albumTrack.name,
                    artist: albumTrack.artist,
                    album: "",
                    albumImageUrl: nil,
                    durationMs: albumTrack.durationMs
                )
                tracks.append(track)
            } else {
                _ = try? itemsContainer.decode(AnyCodable.self)
            }
        }
        items = tracks
    }

    private enum CodingKeys: String, CodingKey {
        case items
    }
}

struct SpotifyUser: Codable {
    let id: String
    let displayName: String?
    let email: String?
    let product: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case email
        case product
    }

    var isPremium: Bool {
        product == "premium"
    }
}

struct SpotifyTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}
