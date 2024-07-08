//
//  PodApp.swift
//  Pod
//
//  Created by Iskren Alexandrov on 22.06.24.
//

import SwiftUI

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
        
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up the window size here
        if let window = NSApplication.shared.windows.first {
            window.setContentSize(NSSize(width: 400, height: 600))
            window.minSize = NSSize(width: 400, height: 600)
            window.maxSize = NSSize(width: 400, height: 600)
        }
    }
}
