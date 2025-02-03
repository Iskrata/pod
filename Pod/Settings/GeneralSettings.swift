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
        VStack(alignment: .leading, spacing: 24) {
            // Music Library Section
            VStack(alignment: .leading, spacing: 16) {
                Label("Music Library", systemImage: "music.note")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 12) {
                    // Folder Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Music Folder")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        
                        MusicFolderSelection()
                    }
                    
                    Divider()
                    
                    // iTunes Toggle
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(isOn: $globalState.includeItunesFolder) {
                            Text("Include iTunes Library")
                        }
                        .toggleStyle(.switch)
                        
                        Text("Also scan the iTunes Music folder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Appearance Section
            VStack(alignment: .leading, spacing: 16) {
                Label("Appearance", systemImage: "paintbrush")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Theme")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    
                    AppearanceSection(selection: $globalState.appearance)
                }
                .padding(12)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Footer
            HStack {
                Text("Version \(getAppVersion())")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                #if DEBUG
                HStack(spacing: 12) {
                    Button(action: {
                        UserDefaults.standard.reset()
                    }) {
                        Label("Reset Settings", systemImage: "arrow.counterclockwise")
                            .foregroundColor(.red)
                    }
                    
                    Button(action: {
                        UserDefaults.standard.set(false, forKey: "hasLaunchedBefore")
                        GlobalState.shared.activeView = .onboarding
                        NSApplication.shared.keyWindow?.close()
                    }) {
                        Label("Restart Onboarding", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(.plain)
                #endif
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    func getAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
}

struct AppearanceSection: View {
    @Binding var selection: String
    let themes = ["System", "Light", "Dark"]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(themes, id: \.self) { theme in
                ThemeButton(
                    title: theme,
                    icon: themeIcon(for: theme),
                    isSelected: selection == theme
                ) {
                    selection = theme
                }
            }
        }
    }
    
    private func themeIcon(for theme: String) -> String {
        switch theme {
        case "System": return "circle.lefthalf.filled"
        case "Light": return "sun.max"
        case "Dark": return "moon"
        default: return ""
        }
    }
}

struct ThemeButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(isSelected ? Color.accentColor : Color.clear)
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

struct MusicFolderSelection: View {
    @StateObject private var globalState = GlobalState.shared
    @State private var showFolderPicker = false
    
    var body: some View {
        Button(action: { showFolderPicker.toggle() }) {
            HStack {
                Image(systemName: "folder")
                Text(globalState.musicFolderDir.isEmpty ? "Choose folder..." : globalState.musicFolderDir)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color.white.opacity(0.5))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
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
