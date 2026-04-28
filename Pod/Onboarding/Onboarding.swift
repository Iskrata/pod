//
//  Onboarding.swift
//  Pod
//
//  Created by Iskren Alexandrov on 8.07.24.
//

import Foundation
import SwiftUI

struct Onboarding: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @StateObject private var radioViewModel = RadioSettingsViewModel()

    private var totalSteps: Int { OnboardingStep.allCases.count }

    var body: some View {
        VStack(spacing: 0) {
            // Top step pills
            HStack(spacing: 4) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i <= viewModel.step.rawValue ? Color.accentColor : Color.gray.opacity(0.25))
                        .frame(height: 3)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            ZStack {
                switch viewModel.step {
                case .welcome:   WelcomeStep().transition(.opacity)
                case .rotate:    RotateStep(viewModel: viewModel).transition(.opacity)
                case .menu:      MenuStep().transition(.opacity)
                case .skip:      SkipStep(viewModel: viewModel).transition(.opacity)
                case .playPause: PlayPauseStep().transition(.opacity)
                case .select:    SelectStep().transition(.opacity)
                case .music:     MusicStep().transition(.opacity)
                case .spotify:   SpotifySetupScreen().transition(.opacity)
                case .radio:     RadioSetupScreen(radioViewModel: radioViewModel).transition(.opacity)
                case .ready:     ReadyStep().transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.step)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .onAppear {
            DispatchQueue.main.async { viewModel.applyHighlight() }
        }
    }
}

// MARK: - Step layouts

private struct StepShell<Content: View>: View {
    let title: String
    let cta: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(cta)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WelcomeStep: View {
    var body: some View {
        StepShell(title: "Welcome to Pod", cta: "Press the glowing center button to begin") {
            VStack(spacing: 8) {
                Image("appIcon")
                    .resizable().aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                Text("A click‑wheel music player on your Mac")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct RotateStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var spin = false

    var body: some View {
        StepShell(title: "Rotate the Wheel", cta: "Drag both directions on the wheel to scroll") {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.25), lineWidth: 4)
                        .frame(width: 70, height: 70)
                    Circle()
                        .trim(from: 0, to: 0.25)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(spin ? 360 : 0))
                        .animation(.linear(duration: 1.6).repeatForever(autoreverses: false), value: spin)
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.accentColor)
                }
                .onAppear { spin = true }

                HStack(spacing: 14) {
                    Check(label: "Clockwise", on: viewModel.hasScrolledDown)
                    Check(label: "Counter‑clockwise", on: viewModel.hasScrolledUp)
                }
            }
        }
    }
}

private struct Check: View {
    let label: String
    let on: Bool
    @State private var scale: CGFloat = 1
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                .foregroundColor(on ? .green : .gray)
                .scaleEffect(scale)
                .onChange(of: on) { v in
                    if v {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { scale = 1.4 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            withAnimation(.spring(response: 0.25)) { scale = 1 }
                        }
                    }
                }
            Text(label).font(.system(size: 12)).foregroundColor(.black)
        }
    }
}

private struct MenuStep: View {
    var body: some View {
        StepShell(title: "MENU goes back", cta: "Press the MENU button on the wheel") {
            VStack(spacing: 10) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.accentColor)
                Text("Use MENU anytime to return to the previous screen.")
                    .font(.system(size: 12))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 240)
            }
        }
    }
}

private struct SkipStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    var body: some View {
        StepShell(title: "Skip & Navigate", cta: "Press both side buttons to continue") {
            VStack(spacing: 10) {
                HStack(spacing: 18) {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 30))
                        .foregroundColor(viewModel.pressedPrev ? .green : .accentColor)
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 30))
                        .foregroundColor(viewModel.pressedNext ? .green : .accentColor)
                }
                Text("Skip songs, jump in lists, or move between options.")
                    .font(.system(size: 12))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 240)
                HStack(spacing: 14) {
                    Check(label: "◀︎", on: viewModel.pressedPrev)
                    Check(label: "▶︎", on: viewModel.pressedNext)
                }
            }
        }
    }
}

private struct PlayPauseStep: View {
    var body: some View {
        StepShell(title: "Play / Pause", cta: "Press the bottom button on the wheel") {
            VStack(spacing: 10) {
                Image(systemName: "playpause.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                Text("Pause and resume whatever's playing.")
                    .font(.system(size: 12))
                    .foregroundColor(.black)
            }
        }
    }
}

private struct SelectStep: View {
    var body: some View {
        StepShell(title: "Center to Select", cta: "Press the glowing center to confirm") {
            VStack(spacing: 10) {
                ZStack {
                    Circle().stroke(Color.accentColor.opacity(0.4), lineWidth: 3).frame(width: 60, height: 60)
                    Circle().fill(Color.accentColor).frame(width: 36, height: 36)
                }
                Text("The center button picks what you've highlighted.")
                    .font(.system(size: 12))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 240)
            }
        }
    }
}

private struct MusicStep: View {
    var body: some View {
        StepShell(title: "Your Music", cta: "Press center to continue") {
            VStack(spacing: 8) {
                Image(systemName: "music.quarternote.3")
                    .font(.system(size: 38))
                    .foregroundColor(.accentColor)
                Text("Drop MP3s into your Music folder, or keep using Apple Music. They'll appear under Local.")
                    .font(.system(size: 12))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }
        }
    }
}

private struct ReadyStep: View {
    var body: some View {
        StepShell(title: "You're all set", cta: "Press center to enter Pod") {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.green)
                Text("Tip: MENU always takes you back. The wheel scrolls. Center selects.")
                    .font(.system(size: 12))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }
        }
    }
}

// MARK: - Setup screens (kept from original flow)

struct SpotifySetupScreen: View {
    @ObservedObject private var spotifyService = SpotifyService.shared

    var body: some View {
        VStack(spacing: 12) {
            Text("Spotify")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)

            if spotifyService.isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.green)

                Text("Connected!")
                    .font(.headline)
                    .foregroundStyle(.black)

                if let user = spotifyService.currentUser {
                    Text(user.displayName ?? user.id)
                        .foregroundColor(.secondary)
                }

                Text("Press center to continue")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 36))
                    .foregroundColor(.green)

                Text("Play Spotify playlists with the click wheel")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 260)

                Button(action: { spotifyService.startAuth() }) {
                    Label("Connect with Spotify", systemImage: "link")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Text("Requires Spotify Premium")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Or press center to skip")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct RadioSetupScreen: View {
    @ObservedObject var radioViewModel: RadioSettingsViewModel

    var body: some View {
        VStack(spacing: 10) {
            Text("Radio Stations")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search radio stations", text: $radioViewModel.searchText)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)

            if radioViewModel.isSearching {
                ProgressView()
            } else if let error = radioViewModel.errorMessage {
                Text(error).foregroundColor(.red)
            } else if !radioViewModel.searchText.isEmpty {
                List {
                    ForEach(radioViewModel.searchResults) { station in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(station.name).foregroundColor(.primary)
                                Text(station.country).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(action: { radioViewModel.toggleFavorite(station) }) {
                                Image(systemName: radioViewModel.isFavorite(station) ? "heart.fill" : "heart")
                                    .foregroundColor(radioViewModel.isFavorite(station) ? .red : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .frame(height: 110)
            } else {
                Text("Search for your favorite radio stations")
                    .foregroundColor(.secondary)
                    .padding()
            }

            Text("You can add more later in Settings · Press center to continue")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    Onboarding(viewModel: OnboardingViewModel())
}
