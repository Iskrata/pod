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
            hapticManager.perform(.generic, performanceTime: .now)
        }
    }

    func wheelDown() {
        if selectedIndex < menuItems.count - 1 {
            selectedIndex += 1
            hapticManager.perform(.generic, performanceTime: .now)
        }
    }

    func middleClick() {
        switch selectedIndex {
        case 0: // Spotify
            enterCategory(.spotify, settingsTab: "Spotify")
        case 1: // Radio
            enterCategory(.radio, settingsTab: "Radio")
        case 2: // Local
            enterCategory(.local, settingsTab: "General")
        case 3: // Settings
            shouldOpenSettings = true
        default:
            break
        }
    }

    private func enterCategory(_ filter: SourceFilter, settingsTab: String) {
        GlobalState.shared.sourceFilter = filter
        let albumVM = GlobalState.shared.albumViewModel
        albumVM.applyFilter()
        GlobalState.shared.activeView = .albums
        if albumVM.filteredAlbums.isEmpty {
            // Auto-open Settings on the relevant tab when the category is empty
            GlobalState.shared.preferredSettingsTab = settingsTab
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                GlobalState.shared.shouldOpenSettings = true
            }
        }
    }

    func menuClick() {}
    func nextClick() { wheelDown() }
    func prevClick() { wheelUp() }
    func playPauseClick() {}
}
