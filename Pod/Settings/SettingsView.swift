//
//  SettingsView.swift
//  Pod
//

import SwiftUI

struct SettingsView: View {
    @State private var selectedTab = "General"

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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenSpotifySettings"))) { _ in
            selectedTab = "Spotify"
        }
    }
}

extension UserDefaults {
    func reset() {
        dictionaryRepresentation().keys.forEach { removeObject(forKey: $0) }
    }
}
