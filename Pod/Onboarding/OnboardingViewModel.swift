//
//  OnboardingViewModel.swift
//  Pod
//
//  Created by Iskren Alexandrov on 8.07.24.
//

import Foundation
import SwiftUI

class OnboardingViewModel: ProtocolView {
    @Published var activeScreen: Int = 0
    private let hapticManager = NSHapticFeedbackManager.defaultPerformer
    
    func inc() {
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        
        if (self.activeScreen < 3) {
            self.activeScreen += 1
        } else {
            objectWillChange.send()
            GlobalState.shared.activeView = 0
        }
    }

    func nextClick() {
        inc()
    }
    
    func prevClick() {
        if (self.activeScreen - 1 > 0) {
            self.activeScreen -= 1
        }
    }
    
    func playPauseClick() {
        inc()
    }
    
    func middleClick() {
        inc()
    }
    
    func wheelUp() {
        self.hapticManager.perform(.alignment, performanceTime: .default)
    }
    
    func wheelDown() {
        self.hapticManager.perform(.alignment, performanceTime: .default)
    }
    
    func menuClick() {
        inc()
    }
    
}
