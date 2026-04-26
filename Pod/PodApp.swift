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
    let info = Bundle.main.infoDictionary
    TelemetryDeck.signal("App.launched", parameters: [
      "bundleId": Bundle.main.bundleIdentifier ?? "unknown",
      "shortVersion": info?["CFBundleShortVersionString"] as? String ?? "unknown",
      "build": info?["CFBundleVersion"] as? String ?? "unknown",
      "feedURL": info?["SUFeedURL"] as? String ?? "unknown",
    ])
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .fixedSize()
        .preferredColorScheme(getColorScheme())
        // OAuth callback now handled by librespot bridge (localhost:5588)
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
    setupKeyboardMonitor()
  }

  private func setupKeyboardMonitor() {
    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      let gs = GlobalState.shared

      // Don't capture keys when settings window is focused
      if NSApp.keyWindow != NSApp.windows.first { return event }

      // Let system shortcuts (Cmd+Q, Cmd+W, Ctrl+…, Opt+…) through
      let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
      if mods.contains(.command) || mods.contains(.control) || mods.contains(.option) {
        return event
      }

      if event.keyCode == 53 { // Escape
        if !gs.searchQuery.isEmpty {
          gs.searchQuery = ""
          return nil
        }
        return event
      }

      if event.keyCode == 51 { // Backspace
        if !gs.searchQuery.isEmpty {
          gs.searchQuery.removeLast()
          return nil
        }
        return event
      }

      // Only allow search on album and main menu screens
      if gs.activeView == .song { return event }

      if let chars = event.characters, !chars.isEmpty {
        let char = chars.first!
        if char.isLetter || char.isNumber || char == " " {
          gs.searchQuery.append(char)
          if gs.activeView != .albums {
            gs.activeView = .albums
          }
          return nil // suppress system sound
        }
      }

      return event
    }
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
