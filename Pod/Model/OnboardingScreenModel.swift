//
//  OnboardingScreen.swift
//  Pod
//
//  Created by Iskren Alexandrov on 8.07.24.
//

import Foundation

struct OnboardingScreenModel: Identifiable {
    var id = UUID()
    
    var title: String
    var iconName: String
    
    var heading: String?
    var description: String?
    
    init(title: String, iconName: String, heading: String? = nil, description: String? = nil) {
        self.title = title
        self.iconName = iconName
        self.heading = heading
        self.description = description
    }
}
    
