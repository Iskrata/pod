//
//  AlbumViewModel.swift
//  Pod
//
//  Created by Iskren Alexandrov on 29.06.24.
//

import SwiftUI
import AVFoundation
import Combine

class AlbumViewModel: ProtocolView {
    var view: AnyView {
        AnyView(AlbumsView(viewModel: self))
    }
    
    @Published var loadUrl: String = ""
    @Published var albums: [Album] = []
    @Published var filteredAlbums: [Album] = []
    @Published var scrollOffset: CGFloat = 0
    @Published var activeIndex: Int = 0
    
    @ObservedObject var settings = GlobalState.shared
    private var cancellables = Set<AnyCancellable>()
    
    private let hapticManager = NSHapticFeedbackManager.defaultPerformer
    
    let fileManager = FileManager.default
    var excludeFolder = ["Music", "PioneerDJ"]
    
    init() {
        self.loadUrl = settings.musicFolderDir
        self.loadDirectories()
        self.loadFavoriteRadioStations()
        self.loadSpotifyPlaylists()
        self.loadSpotifyAlbums()

        settings.$musicFolderDir
            .sink { [weak self] newFolderPath in
                self?.loadUrl = newFolderPath
                self?.loadDirectories()
                self?.loadFavoriteRadioStations()
                self?.loadSpotifyPlaylists()
                self?.loadSpotifyAlbums()
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadFavoriteStations),
            name: NSNotification.Name("FavoriteStationsChanged"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadSpotifyPlaylists),
            name: NSNotification.Name("SpotifyPlaylistsChanged"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSpotifyConnected),
            name: NSNotification.Name("SpotifyConnected"),
            object: nil
        )

        GlobalState.shared.$searchQuery
            .removeDuplicates()
            .sink { [weak self] query in
                self?.applySearchFilter(query)
            }
            .store(in: &cancellables)
    }

    private func applySearchFilter(_ query: String) {
        if query.isEmpty {
            applyFilter()
        } else {
            applyFilter()
            filteredAlbums = filteredAlbums.filter {
                $0.name.localizedCaseInsensitiveContains(query)
            }
        }
        activeIndex = 0
        scrollOffset = 0
    }
    
    @objc private func reloadFavoriteStations() {
        DispatchQueue.main.async { [weak self] in
            self?.albums.removeAll { $0.isRadioStation }
            self?.loadFavoriteRadioStations()
        }
    }

    @objc private func onSpotifyConnected() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.albums.removeAll { $0.isSpotifyPlaylist || $0.isSpotifyAlbum }
            self?.loadSpotifyPlaylists()
            self?.loadSpotifyAlbums()
        }
    }

    @objc private func reloadSpotifyPlaylists() {
        DispatchQueue.main.async { [weak self] in
            self?.albums.removeAll { $0.isSpotifyPlaylist || $0.isSpotifyAlbum }
            self?.loadSpotifyPlaylists()
            self?.loadSpotifyAlbums()
        }
    }
    
    func sortAlbums() {
        albums.sort { album1, album2 in
            // Spotify playlists before Spotify albums
            if album1.isSpotifyPlaylist != album2.isSpotifyPlaylist { return album1.isSpotifyPlaylist }
            if album1.isSpotifyAlbum != album2.isSpotifyAlbum { return album1.isSpotifyAlbum }

            let hasArt1 = album1.coverImage != nil || album1.spotifyImageUrl != nil
            let hasArt2 = album2.coverImage != nil || album2.spotifyImageUrl != nil
            let isUnknown1 = album1.name == "Unknown album"
            let isUnknown2 = album2.name == "Unknown album"

            if hasArt1 != hasArt2 { return hasArt1 }
            if isUnknown1 != isUnknown2 { return !isUnknown1 }
            return album1.name.localizedCaseInsensitiveCompare(album2.name) == .orderedAscending
        }
    }

    func applyFilter() {
        applyFilterKeepIndex()
        activeIndex = 0
    }

    private func applyFilterKeepIndex() {
        guard let filter = GlobalState.shared.sourceFilter else {
            filteredAlbums = albums
            return
        }
        switch filter {
        case .spotify:
            filteredAlbums = albums.filter { $0.isSpotifyPlaylist || $0.isSpotifyAlbum }
        case .radio:
            filteredAlbums = albums.filter { $0.isRadioStation }
        case .local:
            filteredAlbums = albums.filter { !$0.isRadioStation && !$0.isSpotifyPlaylist && !$0.isSpotifyAlbum }
        }
        if activeIndex >= filteredAlbums.count {
            activeIndex = max(0, filteredAlbums.count - 1)
        }
    }
    
    func loadDirectories() {
        albums.removeAll()
        
        let url = URL(fileURLWithPath: loadUrl)
        
        loadDirectories(at: url)
        if settings.includeItunesFolder {
            loadDirectories(at: URL(fileURLWithPath: "\(URL.userHome.path)/Music/Music"))
        }
        
        sortAlbums()
    }
    
    private func loadDirectories(at url: URL) {
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            let directories = contents.filter { $0.hasDirectoryPath }
            let musicFiles = contents.filter { !$0.hasDirectoryPath && $0.pathExtension == "mp3" } // Adjust for other music file extensions if needed
            
            if !musicFiles.isEmpty {
                let albumName = url.lastPathComponent
                
                if excludeFolder.contains(albumName) {
                    return
                }
                
                let coverImage = getAlbumCover(from: url)
                let album = Album(name: albumName, coverImage: coverImage, path: url.path)
                albums.append(album)
            }
            
            for directory in directories {
                loadDirectories(at: directory)
            }
        } catch {
            print("Error loading directories: \(error.localizedDescription)")
        }
    }
    
    private func getAlbumCover(from directoryURL: URL) -> NSImage? {
        do {
            let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            for fileURL in contents where fileURL.pathExtension == "mp3" {
                let asset = AVAsset(url: fileURL)
                for metadataItem in asset.commonMetadata {
                    if metadataItem.commonKey?.rawValue == "artwork", let data = metadataItem.value as? Data, let nsImage = NSImage(data: data) {
                        return nsImage
                    }
                }
            }
        } catch {
            print("Error loading album cover: \(error.localizedDescription)")
        }
        return nil
    }
    
    private func loadFavoriteRadioStations() {
        if let data = UserDefaults.standard.data(forKey: "favoriteStations"),
           let stations = try? JSONDecoder().decode([RadioStation].self, from: data) {

            let radioAlbums = stations.map { station in
                Album(
                    name: station.name,
                    coverImage: NSImage(systemSymbolName: "radio", accessibilityDescription: nil),
                    path: station.id,
                    isRadioStation: true,
                    streamUrl: station.url
                )
            }

            albums.append(contentsOf: radioAlbums)
            sortAlbums()
        }
    }

    private func loadSpotifyPlaylists() {
        let spotifyPlaylists = SpotifyService.shared.selectedPlaylists.map { playlist in
            Album(
                name: playlist.name,
                coverImage: nil,
                path: playlist.id,
                isSpotifyPlaylist: true,
                spotifyPlaylistId: playlist.id,
                spotifyImageUrl: playlist.imageUrl
            )
        }
        NSLog("[AlbumVM] loadSpotifyPlaylists count=\(spotifyPlaylists.count)")
        let uniqueIds = Set(spotifyPlaylists.compactMap { $0.spotifyPlaylistId })
        NSLog("[AlbumVM]   unique playlist ids=\(uniqueIds.count)")
        albums.append(contentsOf: spotifyPlaylists)
        sortAlbums()
        applyFilterKeepIndex()
    }

    private func loadSpotifyAlbums() {
        let spotifyAlbums = SpotifyService.shared.selectedAlbums.map { album in
            Album(
                name: album.name,
                coverImage: nil,
                path: album.id,
                spotifyImageUrl: album.imageUrl,
                isSpotifyAlbum: true,
                spotifyAlbumId: album.id,
                spotifyAlbumUri: album.uri
            )
        }
        NSLog("[AlbumVM] loadSpotifyAlbums count=\(spotifyAlbums.count)")
        for (i, a) in spotifyAlbums.enumerated() {
            NSLog("[AlbumVM]   #\(i) name=\(a.name) id=\(a.spotifyAlbumId ?? "nil") uri=\(a.spotifyAlbumUri ?? "nil")")
        }
        albums.append(contentsOf: spotifyAlbums)
        sortAlbums()
        applyFilterKeepIndex()
    }
    
    func nextClick() {
        
    }
    
    func prevClick() {
        
    }
    
    func playPauseClick() {
    }
    
    func menuClick() {
        GlobalState.shared.searchQuery = ""
        GlobalState.shared.activeView = .mainMenu
    }
    
    func middleClick() {
        NSLog("[AlbumVM] middleClick activeIndex=\(activeIndex) filteredCount=\(filteredAlbums.count)")
        let lo = max(0, activeIndex - 2)
        let hi = min(filteredAlbums.count - 1, activeIndex + 2)
        if hi >= lo {
            for i in lo...hi {
                let a = filteredAlbums[i]
                let kind = a.isSpotifyPlaylist ? "PLST" : (a.isSpotifyAlbum ? "ALBM" : "LOCAL")
                let id = a.spotifyPlaylistId ?? a.spotifyAlbumId ?? a.path
                NSLog("[AlbumVM]   neighbor[\(i)\(i == activeIndex ? "*" : "")] \(kind) name=\(a.name) id=\(id)")
            }
        }
        if filteredAlbums.isEmpty {
            let tab: String?
            switch GlobalState.shared.sourceFilter {
            case .spotify: tab = "Spotify"
            case .radio:   tab = "Radio"
            case .local:   tab = "General"
            case .none:    tab = nil
            }
            if let tab = tab {
                GlobalState.shared.preferredSettingsTab = tab
                GlobalState.shared.shouldOpenSettings = true
            }
            return
        }
        // Snapshot the selection BEFORE touching searchQuery — clearing
        // searchQuery resets activeIndex to 0 via the Combine sink.
        let selectedAlbum = filteredAlbums[activeIndex]
        GlobalState.shared.searchQuery = ""
        print("[AlbumVM] middleClick idx=\(activeIndex) name=\(selectedAlbum.name) isPlaylist=\(selectedAlbum.isSpotifyPlaylist) isAlbum=\(selectedAlbum.isSpotifyAlbum)")

        if selectedAlbum.isRadioStation {
            if let streamUrl = selectedAlbum.streamUrl {
                GlobalState.shared.songViewModel.playRadioStation(
                    url: streamUrl,
                    name: selectedAlbum.name
                )
            }
        } else if selectedAlbum.isSpotifyPlaylist {
            if let playlistId = selectedAlbum.spotifyPlaylistId {
                GlobalState.shared.songViewModel.playSpotifyPlaylist(
                    playlistId: playlistId,
                    playlistName: selectedAlbum.name,
                    imageUrl: selectedAlbum.spotifyImageUrl
                )
            }
        } else if selectedAlbum.isSpotifyAlbum {
            if let albumId = selectedAlbum.spotifyAlbumId, let albumUri = selectedAlbum.spotifyAlbumUri {
                NSLog("[AlbumVM] play Spotify album name=\(selectedAlbum.name) id=\(albumId) uri=\(albumUri)")
                GlobalState.shared.songViewModel.playSpotifyAlbum(
                    albumId: albumId,
                    albumUri: albumUri,
                    albumName: selectedAlbum.name,
                    imageUrl: selectedAlbum.spotifyImageUrl
                )
            } else {
                NSLog("[AlbumVM] Spotify album missing id/uri name=\(selectedAlbum.name) id=\(selectedAlbum.spotifyAlbumId ?? "nil") uri=\(selectedAlbum.spotifyAlbumUri ?? "nil")")
            }
        } else {
            GlobalState.shared.selectedAlbumDir = selectedAlbum.path
            GlobalState.shared.activeView = .song
        }
    }
    
    func wheelUp(){
        if filteredAlbums.isEmpty { return }
        if activeIndex > 0 {
            activeIndex -= 1
            hapticManager.perform(.generic, performanceTime: .now)
        }
        GlobalState.shared.selectedAlbumDir = filteredAlbums[activeIndex].path
        NSLog("[AlbumVM] wheelUp -> activeIndex=\(activeIndex) name=\(filteredAlbums[activeIndex].name)")
    }

    func wheelDown(){
        if filteredAlbums.isEmpty { return }
        if activeIndex < filteredAlbums.count - 1 {
            activeIndex += 1
            hapticManager.perform(.generic, performanceTime: .now)
        }
        GlobalState.shared.selectedAlbumDir = filteredAlbums[activeIndex].path
        NSLog("[AlbumVM] wheelDown -> activeIndex=\(activeIndex) name=\(filteredAlbums[activeIndex].name)")
    }
}
