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
        
        settings.$musicFolderDir
            .sink { [weak self] newFolderPath in
                self?.loadUrl = newFolderPath
                self?.loadDirectories()
            }
            .store(in: &cancellables)
    }
    
    func sortAlbums() {
        albums.sort { (album1, album2) -> Bool in
            if let cover1 = album1.coverImage, let cover2 = album2.coverImage {
                return true
            } else if album1.coverImage != nil {
                return true
            } else if album2.coverImage != nil {
                return false
            } else {
                if album1.name == "Unknown album" && album2.name != "Unknown album" {
                    return false
                } else if album2.name == "Unknown album" && album1.name != "Unknown album" {
                    return true
                } else {
                    return true
                }
            }
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
    
    func nextClick() {
        
    }
    
    func prevClick() {
        
    }
    
    func playPauseClick() {
    }
    
    func menuClick() {
    }
    
    func middleClick() {
        GlobalState.shared.selectedAlbumDir = albums[activeIndex].path
        GlobalState.shared.activeView = .song
    }
    
    func wheelUp(){
        if albums.isEmpty {
            return
        }
        
        if (activeIndex > 0)
        {
            activeIndex -= 1
            self.hapticManager.perform(.alignment, performanceTime: .drawCompleted)
        }
        GlobalState.shared.selectedAlbumDir = albums[activeIndex].path
    }
    
    func wheelDown(){
        if albums.isEmpty {
            return
        }
        
        if (activeIndex < albums.count - 1)
        {
            activeIndex += 1
            self.hapticManager.perform(.alignment, performanceTime: .drawCompleted)
        }
        GlobalState.shared.selectedAlbumDir = albums[activeIndex].path
    }
}
