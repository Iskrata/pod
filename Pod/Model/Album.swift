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
    var coverImage: Image?
    var path: String
    
    init(name: String, coverImage: Image? = nil, path: String) {
        self.name = name
        self.coverImage = coverImage
        self.path = path
    }
    
}
