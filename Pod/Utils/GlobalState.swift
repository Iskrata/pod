//
//  GlobalState.swift
//  Pod
//
//  Created by Iskren Alexandrov on 29.06.24.
//
import SwiftUI

class GlobalState {
    static let shared = GlobalState()
    
    var selectedAlbumDir: String = ""
    var musicFolderDir: String = "\(URL.userHome.path)/Music"
    
    var activeView: Int = UserDefaults.standard.bool(forKey: "hasLaunchedBefore") ? 0 : 2
    var viewCount: Int = 2
    
    private init() { }
}
