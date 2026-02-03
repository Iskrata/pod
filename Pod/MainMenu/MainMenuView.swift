//
//  MainMenuView.swift
//  Pod
//

import SwiftUI

struct MainMenuView: View {
    @ObservedObject var viewModel: MainMenuViewModel

    var body: some View {
        VStack(spacing: 0) {
            MenuBar(title: "Main Menu", isPlaying: GlobalState.shared.songViewModel.isPlaying)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.menuItems.enumerated()), id: \.offset) { index, item in
                    HStack(spacing: 12) {
                        Image(systemName: viewModel.menuIcons[index])
                            .frame(width: 20)
                        Text(item)
                            .font(.system(size: 16))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(index == viewModel.selectedIndex ? Color.blue : Color.clear)
                    .foregroundColor(index == viewModel.selectedIndex ? .white : .black)
                }
            }

            Spacer()
        }
        .modifier(SettingsOpenerModifier(shouldOpen: $viewModel.shouldOpenSettings))
    }
}

struct SettingsOpenerModifier: ViewModifier {
    @Binding var shouldOpen: Bool

    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.modifier(SettingsOpenerModifier14(shouldOpen: $shouldOpen))
        } else {
            content.modifier(SettingsOpenerModifierLegacy(shouldOpen: $shouldOpen))
        }
    }
}

@available(macOS 14.0, *)
struct SettingsOpenerModifier14: ViewModifier {
    @Binding var shouldOpen: Bool
    @Environment(\.openSettings) private var openSettings

    func body(content: Content) -> some View {
        content.onChange(of: shouldOpen) { shouldOpen in
            if shouldOpen {
                openSettings()
                self.shouldOpen = false
            }
        }
    }
}

struct SettingsOpenerModifierLegacy: ViewModifier {
    @Binding var shouldOpen: Bool

    func body(content: Content) -> some View {
        content.onChange(of: shouldOpen) { shouldOpen in
            if shouldOpen {
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                self.shouldOpen = false
            }
        }
    }
}
