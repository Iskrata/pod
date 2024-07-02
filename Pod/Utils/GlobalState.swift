//
//  GlobalState.swift
//  Pod
//
//  Created by Iskren Alexandrov on 29.06.24.
//
import SwiftUI

//class GlobalState: ObservableObject {
//    @Published var selectedAlbumDir = "/Users/iskrenalexandrov/Music/IGOR"
//}

class GlobalState {
    static let shared = GlobalState()
    var selectedAlbumDir = ""
    var musicFolderDir = "\(URL.userHome.path)/Music"
    
    private init() { }
}
