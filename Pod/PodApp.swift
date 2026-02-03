//
//  PodApp.swift
//  Pod
//
//  Created by Iskren Alexandrov on 22.06.24.
//

import Cocoa
import SwiftUI
import TelemetryDeck
import Sparkle

@main
struct PodApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @StateObject var globalState = GlobalState.shared

  func getColorScheme() -> ColorScheme? {
    switch globalState.appearance {
    case "Dark":
      .dark
    case "Light":
      .light
    default:
      nil
    }
  }

  init() {
    let config = TelemetryDeck.Config(appID: "9B3B75EC-D70D-4B62-902C-2967F932F84B")
    TelemetryDeck.initialize(config: config)
    TelemetryDeck.signal("App.launched")
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .fixedSize()
        .preferredColorScheme(getColorScheme())
        .onOpenURL { url in
          if url.scheme == "pod" && url.host == "callback" {
            SpotifyService.shared.handleCallback(url: url)
          }
        }
    }
    .applyWindowResizability()

    Settings {
      SettingsView()
    }
  }
}

extension Scene {
  func applyWindowResizability() -> some Scene {
    if #available(macOS 13.0, *) {
      return self.windowResizability(.contentSize)
    } else {
      return self
    }
  }
}

class AppDelegate: NSObject, NSApplicationDelegate {
  var window: NSWindow!
  private var updaterController: SPUStandardUpdaterController!

  func applicationDidFinishLaunching(_ notification: Notification) {
    configureWindow()
    updaterController = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: nil,
      userDriverDelegate: nil
    )
  }

  private func configureWindow() {
    if let window = NSApplication.shared.windows.first {
      let size = NSSize(width: 400, height: 600)
      window.setContentSize(size)
      window.minSize = size
      window.maxSize = size
    }
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}
