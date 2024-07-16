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

extension UserDefaults {
    func reset() {
        let dictionary = self.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            self.removeObject(forKey: key)
        }
    }
}


struct GeneralSettingsView: View {
    @StateObject private var globalState = GlobalState.shared
    
    var body: some View {
        VStack {
            MusicFolderSelection()
            AppearanceSection(selection: $globalState.appearance)
            Spacer()
#if DEBUG
            Button(action: {
                UserDefaults.standard.reset()
            }, label: {
                Label("Emit UserDefaults Data", systemImage: "circle")
            })
            .padding()
#endif
        }
    }
}

struct AppearanceSection: View {
    @Binding var selection: String
    let colors = ["System", "Light", "Dark"]
    
    var body: some View {
        HStack {
            Spacer(minLength: 60)
            Picker("Appearance:", selection: $selection) {
                ForEach(colors, id: \.self) {
                    Text($0)
                }
            }
            .pickerStyle(.menu)
            Spacer(minLength: 60)
        }
        .padding()
    }
}

struct MusicFolderSelection: View {
    @StateObject private var globalState = GlobalState.shared
    @State private var showFolderPicker = false
    
    var body: some View {
        HStack {
            Spacer(minLength: 60)
            Text("Music Folder:")
            Button(action: {
                showFolderPicker.toggle()
            }) {
                Text("\(globalState.musicFolderDir.isEmpty ? "Not Selected" : globalState.musicFolderDir)")
                    .padding(2)
                    .help("\(globalState.musicFolderDir.isEmpty ? "Not Selected" : globalState.musicFolderDir)")
            }
            Spacer(minLength: 60)
        }.fileImporter(isPresented: $showFolderPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    if url.startAccessingSecurityScopedResource() {
                        
                        globalState.musicFolderDir = url.path
                        saveFolderBookmark(url: url)
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            case .failure(let error):
                print("Failed to pick folder: \(error.localizedDescription)")
            }
        }
        .padding()
        
    }
    
    func saveFolderBookmark(url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: "musicFolderBookmark")
            
            globalState.restoreBookmarkData(bookmarkData)
        } catch {
            print("Failed to save bookmark data: \(error)")
        }
    }
}

#Preview {
    SettingsView()
}
