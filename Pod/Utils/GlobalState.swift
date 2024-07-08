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
    
    var activeView: Int = 0
    var viewCount: Int = 2
    
    private init() { }
}
