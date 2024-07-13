//
//  PodApp.swift
//  Pod
//
//  Created by Iskren Alexandrov on 22.06.24.
//

import SwiftUI
import Cocoa

@main
struct PodApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .fixedSize()
                .preferredColorScheme(.light)
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
        print("App is running in Debug mode")
        #else
        UpdateChecker.shared.checkForUpdates()
        #endif
    }
}


