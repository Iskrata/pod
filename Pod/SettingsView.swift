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
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape.fill")
                }
        }
        .frame(width: 450, height: 250)
    }
    
}

struct GeneralSettingsView: View {
    @State private var showFolderPicker = false
    @StateObject private var settings = GlobalState.shared

    var body: some View {
        HStack {
            Text("Music Folder: \(settings.musicFolderDir.isEmpty ? "Not Selected" : settings.musicFolderDir)")
                            .padding()
                        
                        Button(action: {
                            showFolderPicker.toggle()
                        }) {
                            Text("Select Music Folder")
                        }
                        .padding()
            
        }.fileImporter(isPresented: $showFolderPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    if url.startAccessingSecurityScopedResource() {
                        settings.musicFolderDir = url.path
                        saveFolderBookmark(url: url)
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            case .failure(let error):
                print("Failed to pick folder: \(error.localizedDescription)")
            }
        }
    }
    
    func saveFolderBookmark(url: URL) {
            do {
                let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                UserDefaults.standard.set(bookmarkData, forKey: "musicFolderBookmark")
            } catch {
                print("Failed to save bookmark data: \(error)")
            }
        }
}
