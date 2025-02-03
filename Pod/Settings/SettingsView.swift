//
//  SettingsView.swift
//  Pod
//
//  Created by Iskren Alexandrov on 10.07.24.
//

import SwiftUI

struct SettingsView: View {
    @State private var selectedTab = "General"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ScrollView {
                GeneralSettings()
                    .padding()
            }
            .tag("General")
            .tabItem {
                Label("General", systemImage: "gearshape.fill")
            }
            
            RadioSettings()
            .tag("Radio")
            .tabItem {
                Label("Radio", systemImage: "radio")
            }
            
            ScrollView {
                ContactUs()
                    .padding()
            }
            .tag("Help")
            .tabItem { 
                Label("Help", systemImage: "questionmark.circle")
            }
        }
        .frame(width: 500)
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
