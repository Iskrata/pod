//
//  GeneralSettings.swift
//  Pod
//
//  Created by Iskren Alexandrov on 24.07.24.
//

import SwiftUI

struct GeneralSettings: View {
    @StateObject private var globalState = GlobalState.shared
    
    var body: some View {
        Form {
            Section("Music folder") {
                MusicFolderSelection()
            }
            Toggle(isOn: $globalState.includeItunesFolder) {
                Text("Include iTunes Music")
            }
            .toggleStyle(.checkbox)
            Spacer(minLength: 30)
            AppearanceSection(selection: $globalState.appearance)
            #if DEBUG
            Button(action: {
                UserDefaults.standard.reset()
            }, label: {
                Label("Emit UserDefaults Data", systemImage: "circle")
            })
            #endif
        }
        .fixedSize()
        .padding()
    }
    
//    var body: some View {
//        HStack {
//            VStack {
//                Text("Music Folder:")
//                Spacer()
//            }
//            VStack {
//                MusicFolderSelection()
//                IncludeItunes(include: $globalState.includeItunesFolder)
//                AppearanceSection(selection: $globalState.appearance)
//                Spacer()
//#if DEBUG
//                Button(action: {
//                    UserDefaults.standard.reset()
//                }, label: {
//                    Label("Emit UserDefaults Data", systemImage: "circle")
//                })
//#endif
//            }
//            
//            
//        }
//    }
}

struct AppearanceSection: View {
    @Binding var selection: String
    let colors = ["System", "Light", "Dark"]
    
    var body: some View {
        Picker("Appearance:", selection: $selection) {
            ForEach(colors, id: \.self) {
                Text($0)
            }
        }
        .pickerStyle(.menu)
    }
}

struct MusicFolderSelection: View {
    @StateObject private var globalState = GlobalState.shared
    @State private var showFolderPicker = false
    
    var body: some View {
            Button(action: {
                showFolderPicker.toggle()
            })
            {
                Text("\(globalState.musicFolderDir.isEmpty ? "Not Selected" : globalState.musicFolderDir)")
                    .help("\(globalState.musicFolderDir.isEmpty ? "Not Selected" : globalState.musicFolderDir)")
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
