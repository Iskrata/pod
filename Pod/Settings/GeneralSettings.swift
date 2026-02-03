//
//  GeneralSettings.swift
//  Pod
//

import SwiftUI

struct GeneralSettings: View {
    @StateObject private var globalState = GlobalState.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsSection(title: "Music Library", icon: "music.note") {
                    SettingsRow(title: "Music Folder") {
                        MusicFolderPicker()
                    }

                    Divider()

                    ToggleRow(
                        "Include iTunes Library",
                        subtitle: "Also scan ~/Music/Music folder",
                        isOn: $globalState.includeItunesFolder
                    )
                }

                SettingsSection(title: "Appearance", icon: "paintbrush") {
                    SettingsRow(title: "Theme") {
                        ThemePicker(selection: $globalState.appearance)
                    }
                }

                Spacer()

                footer
            }
            .padding(20)
        }
    }

    private var footer: some View {
        HStack {
            Text("Version \(appVersion)")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            #if DEBUG
            debugButtons
            #endif
        }
    }

    #if DEBUG
    private var debugButtons: some View {
        HStack(spacing: 12) {
            Button(action: { UserDefaults.standard.reset() }) {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .foregroundColor(.red)
            }
            Button(action: restartOnboarding) {
                Label("Onboarding", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundColor(.blue)
            }
        }
        .font(.caption)
        .buttonStyle(.plain)
    }

    private func restartOnboarding() {
        UserDefaults.standard.set(false, forKey: "hasLaunchedBefore")
        GlobalState.shared.activeView = .onboarding
        NSApplication.shared.keyWindow?.close()
    }
    #endif

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
}

// MARK: - Music Folder Picker

struct MusicFolderPicker: View {
    @StateObject private var globalState = GlobalState.shared
    @State private var showPicker = false

    var body: some View {
        Button(action: { showPicker = true }) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.accentColor)
                Text(displayPath)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderSelection(result)
        }
    }

    private var displayPath: String {
        globalState.musicFolderDir.isEmpty ? "Choose folder..." : globalState.musicFolderDir
    }

    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        globalState.musicFolderDir = url.path
        saveBookmark(for: url)
    }

    private func saveBookmark(for url: URL) {
        guard let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) else { return }
        UserDefaults.standard.set(data, forKey: "musicFolderBookmark")
        globalState.restoreBookmarkData(data)
    }
}

// MARK: - Theme Picker

struct ThemePicker: View {
    @Binding var selection: String

    private let themes: [(name: String, icon: String)] = [
        ("Light", "sun.max.fill"),
        ("Dark", "moon.fill")
    ]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(themes, id: \.name) { theme in
                ThemeOption(
                    name: theme.name,
                    icon: theme.icon,
                    isSelected: selection == theme.name
                ) {
                    selection = theme.name
                }
            }
        }
    }
}

struct ThemeOption: View {
    let name: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(width: 80, height: 60)
            .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
