//
//  GlobalState.swift
//  Pod
//
//  Created by Iskren Alexandrov on 29.06.24.
//
import SwiftUI

class GlobalState: ObservableObject {
    static let shared = GlobalState()
    
    private let ONBOARDING_VERSION = "1.1"
    
    var songViewModel = SongViewModel()
    lazy var albumViewModel = AlbumViewModel()
    lazy var mainMenuViewModel = MainMenuViewModel()
    var selectedAlbumDir: String = ""

    @Published var sourceFilter: SourceFilter?
    
    private init() {
        let savedVersion = UserDefaults.standard.string(forKey: "onboardingVersion")
        if savedVersion != ONBOARDING_VERSION {
            UserDefaults.standard.removeObject(forKey: "hasLaunchedBefore")
            UserDefaults.standard.set(ONBOARDING_VERSION, forKey: "onboardingVersion")
        }
        
        if let bookmarkData = UserDefaults.standard.data(forKey: "musicFolderBookmark") {
            restoreBookmarkData(bookmarkData)
        }
    }
    
    @Published var includeItunesFolder: Bool = UserDefaults.standard.object(forKey: "includeItunesFolder") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(includeItunesFolder, forKey: "includeItunesFolder")
        }
    }
    
    @Published var musicFolderDir: String = UserDefaults.standard.string(forKey: "musicFolderPath") ?? "\(URL.userHome.path)/Music" {
        didSet {
            UserDefaults.standard.set(musicFolderDir, forKey: "musicFolderPath")
        }
    }
    
    @Published var activeView: Screen = UserDefaults.standard.bool(forKey: "hasLaunchedBefore") ? .mainMenu : .onboarding
    
    @Published var appearance: String = UserDefaults.standard.string(forKey: "appearance") ?? "Light" {
        didSet {
            UserDefaults.standard.set(appearance, forKey: "appearance")
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
