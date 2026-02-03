//
//  ContentView.swift
//  Pod
//
//  Created by Iskren Alexandrov on 22.06.24.
//

import AppKit
import SwiftUI

struct DiagonalBackgroundView: View {
  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Color.base
          .edgesIgnoringSafeArea(.all)

        Path { path in
          let width = geometry.size.width
          let height = geometry.size.height

          path.move(to: CGPoint(x: width, y: height - 30))
          path.addLine(to: CGPoint(x: 30, y: 0))
          path.addLine(to: CGPoint(x: width, y: 0))
          path.addLine(to: CGPoint(x: width, y: height - 30))
        }
        .fill(.subBase)
      }
    }.clipped()
  }
}

struct ContentView: View {
  @AppStorage("fontSize") var fontSize = 13.0
  @AppStorage("hasShownSpotifyAlert") var hasShownSpotifyAlert = false
  @State private var showSpotifyAlert = false

  @StateObject private var globalState = GlobalState.shared

  private let views: [Screen: any ProtocolView] = [
    .onboarding: OnboardingViewModel(),
    .mainMenu: GlobalState.shared.mainMenuViewModel,
    .song: GlobalState.shared.songViewModel,
    .albums: GlobalState.shared.albumViewModel,
  ]

  var body: some View {
    ZStack {
      VStack {
        Rectangle()
          .fill(Color.white)
          .frame(width: 320, height: 240)
          .overlay(
            ZStack {
              if let currentView = views[globalState.activeView]?.view {
                AnyView(currentView)
              } else {
                Text("No View Available")
              }
            }
          )
          .border(Color.black, width: 4)
          .shadow(radius: 10)
          .cornerRadius(5)

        Spacer()

        ClickWheel(views: views)
      }
      .padding()
    }
    .background(DiagonalBackgroundView())
    .onAppear {
      if !hasShownSpotifyAlert && globalState.activeView != .onboarding {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
          showSpotifyAlert = true
        }
      }
    }
    .modifier(SpotifyAlertModifier(
      isPresented: $showSpotifyAlert,
      hasShownSpotifyAlert: $hasShownSpotifyAlert
    ))
  }
}

struct SpotifyAlertModifier: ViewModifier {
  @Binding var isPresented: Bool
  @Binding var hasShownSpotifyAlert: Bool

  func body(content: Content) -> some View {
    if #available(macOS 14.0, *) {
      content.modifier(SpotifyAlertModifier14(
        isPresented: $isPresented,
        hasShownSpotifyAlert: $hasShownSpotifyAlert
      ))
    } else {
      content.modifier(SpotifyAlertModifierLegacy(
        isPresented: $isPresented,
        hasShownSpotifyAlert: $hasShownSpotifyAlert
      ))
    }
  }
}

@available(macOS 14.0, *)
struct SpotifyAlertModifier14: ViewModifier {
  @Binding var isPresented: Bool
  @Binding var hasShownSpotifyAlert: Bool
  @Environment(\.openSettings) private var openSettings

  func body(content: Content) -> some View {
    content.alert("Spotify Integration", isPresented: $isPresented) {
      Button("Open Settings") {
        hasShownSpotifyAlert = true
        openSettings()
        NotificationCenter.default.post(name: NSNotification.Name("OpenSpotifySettings"), object: nil)
      }
      Button("Maybe Later", role: .cancel) {
        hasShownSpotifyAlert = true
      }
    } message: {
      Text("You can now play your Spotify playlists in Pod! Requires Spotify Premium.")
    }
  }
}

struct SpotifyAlertModifierLegacy: ViewModifier {
  @Binding var isPresented: Bool
  @Binding var hasShownSpotifyAlert: Bool

  func body(content: Content) -> some View {
    content.alert("Spotify Integration", isPresented: $isPresented) {
      Button("Open Settings") {
        hasShownSpotifyAlert = true
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NotificationCenter.default.post(name: NSNotification.Name("OpenSpotifySettings"), object: nil)
      }
      Button("Maybe Later", role: .cancel) {
        hasShownSpotifyAlert = true
      }
    } message: {
      Text("You can now play your Spotify playlists in Pod! Requires Spotify Premium.")
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
