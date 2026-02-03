//
//  Album.swift
//  Pod
//
//  Created by Iskren Alexandrov on 29.06.24.
//

import Foundation
import SwiftUI

struct Album: Identifiable {

    let id = UUID()
    var name: String
    var coverImage: NSImage?
    var path: String
    var isRadioStation: Bool
    var streamUrl: String?
    var isSpotifyPlaylist: Bool
    var spotifyPlaylistId: String?
    var spotifyImageUrl: String?
    var isSpotifyAlbum: Bool
    var spotifyAlbumId: String?
    var spotifyAlbumUri: String?

    init(name: String, coverImage: NSImage? = nil, path: String, isRadioStation: Bool = false, streamUrl: String? = nil,
         isSpotifyPlaylist: Bool = false, spotifyPlaylistId: String? = nil, spotifyImageUrl: String? = nil,
         isSpotifyAlbum: Bool = false, spotifyAlbumId: String? = nil, spotifyAlbumUri: String? = nil) {
        self.name = name
        self.coverImage = coverImage
        self.path = path
        self.isRadioStation = isRadioStation
        self.streamUrl = streamUrl
        self.isSpotifyPlaylist = isSpotifyPlaylist
        self.spotifyPlaylistId = spotifyPlaylistId
        self.spotifyImageUrl = spotifyImageUrl
        self.isSpotifyAlbum = isSpotifyAlbum
        self.spotifyAlbumId = spotifyAlbumId
        self.spotifyAlbumUri = spotifyAlbumUri
    }

}
