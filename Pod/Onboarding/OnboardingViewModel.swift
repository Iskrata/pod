//
//  OnboardingViewModel.swift
//  Pod
//
//  Created by Iskren Alexandrov on 8.07.24.
//

import Foundation
import SwiftUI

class OnboardingViewModel: ProtocolView {
    var view: AnyView {
           AnyView(Onboarding(viewModel: self))
       }
    
    @Published var activeScreen: Int = 0
    @Published var hasScrolledUp = false
    @Published var hasScrolledDown = false
    private let hapticManager = NSHapticFeedbackManager.defaultPerformer
    
    func inc() {
        if (self.activeScreen < 4) {
            if self.activeScreen == 1 && !(hasScrolledUp && hasScrolledDown) {
                return
            }
            self.activeScreen += 1
        } else {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            GlobalState.shared.activeView = .mainMenu
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
        self.hapticManager.perform(.generic, performanceTime: .now)
        if self.activeScreen == 1 {
            hasScrolledUp = true
        }
    }
    
    func wheelDown() {
        self.hapticManager.perform(.generic, performanceTime: .now)
        if self.activeScreen == 1 {
            hasScrolledDown = true
        }
    }
    
    func menuClick() {
        inc()
    }
    
}
