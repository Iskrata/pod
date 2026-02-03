//
//  MainMenuViewModel.swift
//  Pod
//

import SwiftUI

class MainMenuViewModel: ProtocolView {
    var view: AnyView {
        AnyView(MainMenuView(viewModel: self))
    }

    @Published var selectedIndex = 0
    @Published var shouldOpenSettings = false
    let menuItems = ["Spotify", "Radio", "Local", "Settings"]
    let menuIcons = ["music.note", "radio", "folder", "gearshape"]

    private let hapticManager = NSHapticFeedbackManager.defaultPerformer

    func wheelUp() {
        if selectedIndex > 0 {
            selectedIndex -= 1
            hapticManager.perform(.levelChange, performanceTime: .drawCompleted)
        }
    }

    func wheelDown() {
        if selectedIndex < menuItems.count - 1 {
            selectedIndex += 1
            hapticManager.perform(.levelChange, performanceTime: .drawCompleted)
        }
    }

    func middleClick() {
        switch selectedIndex {
        case 0: // Spotify
            GlobalState.shared.sourceFilter = .spotify
            GlobalState.shared.albumViewModel.applyFilter()
            GlobalState.shared.activeView = .albums
        case 1: // Radio
            GlobalState.shared.sourceFilter = .radio
            GlobalState.shared.albumViewModel.applyFilter()
            GlobalState.shared.activeView = .albums
        case 2: // Local
            GlobalState.shared.sourceFilter = .local
            GlobalState.shared.albumViewModel.applyFilter()
            GlobalState.shared.activeView = .albums
        case 3: // Settings
            shouldOpenSettings = true
        default:
            break
        }
    }

    func menuClick() {}
    func nextClick() {}
    func prevClick() {}
    func playPauseClick() {}
}
