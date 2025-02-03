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
            .tabItem {
                Label("General", systemImage: "gearshape.fill")
            }
            .tag("General")
            
            RadioSettings()
                .tabItem {
                    Label("Radio", systemImage: "radio")
                }
                .tag("Radio")
            
            ScrollView {
                ContactUs()
                    .padding()
            }
            .tabItem { 
                Label("Help", systemImage: "questionmark.circle")
            }
            .tag("Help")
        }
        .frame(width: 450)
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
