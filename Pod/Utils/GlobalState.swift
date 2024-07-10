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
    
    @AppStorage("musicFolderPath") var musicFolderDir: String = "\(URL.userHome.path)/Music"
    
    var activeView: Int = UserDefaults.standard.bool(forKey: "hasLaunchedBefore") ? 0 : 2
    var viewCount: Int = 2
    
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
