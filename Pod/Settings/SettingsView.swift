//
//  SettingsView.swift
//  Pod
//
//  Created by Iskren Alexandrov on 10.07.24.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem {
                    Label("General", systemImage: "gearshape.fill")
                }
            RadioSettings()
                .tabItem {
                    Label("Radio", systemImage: "radio")
                }
            ContactUs()
                .tabItem { Label("Help", systemImage: "questionmark.circle") }
        }
        .frame(width: 450, height: 250)
    }
    
}

extension UserDefaults {
    func reset() {
        let dictionary = self.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            self.removeObject(forKey: key)
        }
    }
}

#Preview {
    SettingsView()
}
