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
    
    func checkForUpdates() {
        guard let url = URL(string: "https://raw.githubusercontent.com/Iskrata/pod-public/main/version.json?cachebust=\(UUID().uuidString)") else {
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("Failed to fetch update info")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let latestVersion = json["version"] as? String,
                   let downloadURL = json["download_url"] as? String {
                    
                    let nsObject: AnyObject? = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as AnyObject
                    let version = nsObject as! String
                    print(version)
                    print(latestVersion)
                    
                    if (version != latestVersion){
                        DispatchQueue.main.async {
                            self.showUpdateAlert(downloadURL: downloadURL)
                        }
                    }
                }
            } catch {
                print("Failed to parse update info")
            }
        }
        
        task.resume()
    }

    func showUpdateAlert(downloadURL: String) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "A new version of the app is available. Please download the latest version."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: downloadURL) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
         // This code will be run while installing from Xcode
        #else
        checkForUpdates()
        #endif
        
        // Set up the window size here
        if let window = NSApplication.shared.windows.first {
            window.setContentSize(NSSize(width: 400, height: 600))
            window.minSize = NSSize(width: 400, height: 600)
            window.maxSize = NSSize(width: 400, height: 600)
        }
    }
}


