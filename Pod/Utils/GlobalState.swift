//
//  GlobalState.swift
//  Pod
//
//  Created by Iskren Alexandrov on 29.06.24.
//
import SwiftUI

class GlobalState: ObservableObject {
    static let shared = GlobalState()
    
    var selectedAlbumDir: String = ""
    
    var songViewModel = SongViewModel()
    
    @Published var musicFolderDir: String = UserDefaults.standard.string(forKey: "musicFolderPath") ?? "\(URL.userHome.path)/Music" {
        didSet {
            UserDefaults.standard.set(musicFolderDir, forKey: "musicFolderPath")
        }
    }
    
    @Published var activeView: Screen = UserDefaults.standard.bool(forKey: "hasLaunchedBefore") ? .albums : .onboarding
        
    private init() {
        if let bookmarkData = UserDefaults.standard.data(forKey: "musicFolderBookmark") {
            restoreBookmarkData(bookmarkData)
        }
    }
    
    func restoreBookmarkData(_ bookmarkData: Data) {
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            if !isStale {
                if url.startAccessingSecurityScopedResource() {
                    musicFolderDir = url.path
                }
            } else {
                // Handle stale bookmark data
                print("Bookmark data is stale.")
            }
        } catch {
            print("Failed to resolve bookmark data: \(error)")
        }
    }
}
