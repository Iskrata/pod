//
//  PodApp.swift
//  Pod
//
//  Created by Iskren Alexandrov on 22.06.24.
//

import SwiftUI
import Cocoa
import TelemetryDeck

@main
struct PodApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var globalState = GlobalState.shared
    @StateObject var licenseManager = LicenseManager.shared
    
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
        }
        .windowResizability(.contentSize)
        
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        configureWindow()
        checkForUpdatesIfNeeded()
    }
    
    private func configureWindow() {
        if let window = NSApplication.shared.windows.first {
            let size = NSSize(width: 400, height: 600)
            window.setContentSize(size)
            window.minSize = size
            window.maxSize = size
        }
    }
    
    private func checkForUpdatesIfNeeded() {
#if DEBUG
//        print("App is running in Debug mode")
#else
        UpdateChecker.shared.checkForUpdates()
#endif
    }
}


