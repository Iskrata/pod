//
//  SettingsView.swift
//  Pod
//

import SwiftUI

struct SettingsView: View {
    @State private var selectedTab = "General"
    @ObservedObject private var globalState = GlobalState.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettings()
                .tag("General")
                .tabItem { Label("General", systemImage: "gearshape.fill") }

            SpotifySettings()
                .tag("Spotify")
                .tabItem { Label("Spotify", systemImage: "music.note") }

            RadioSettings()
                .tag("Radio")
                .tabItem { Label("Radio", systemImage: "radio") }

            ContactUs()
                .tag("Help")
                .tabItem { Label("Help", systemImage: "questionmark.circle") }
        }
        .frame(width: 600, height: 450)
        .onAppear {
            if let tab = globalState.preferredSettingsTab {
                selectedTab = tab
                globalState.preferredSettingsTab = nil
            }
        }
        .onChange(of: globalState.preferredSettingsTab) { tab in
            if let tab = tab {
                selectedTab = tab
                globalState.preferredSettingsTab = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenSpotifySettings"))) { _ in
            selectedTab = "Spotify"
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenRadioSettings"))) { _ in
            selectedTab = "Radio"
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenGeneralSettings"))) { _ in
            selectedTab = "General"
        }
    }
}

extension UserDefaults {
    func reset() {
        dictionaryRepresentation().keys.forEach { removeObject(forKey: $0) }
    }
}
