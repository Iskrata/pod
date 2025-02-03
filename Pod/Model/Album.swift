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
    
    init(name: String, coverImage: NSImage? = nil, path: String, isRadioStation: Bool = false, streamUrl: String? = nil) {
        self.name = name
        self.coverImage = coverImage
        self.path = path
        self.isRadioStation = isRadioStation
        self.streamUrl = streamUrl
    }
    
}
