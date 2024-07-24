//
//  UpdateChecker.swift
//  Pod
//
//  Created by Iskren Alexandrov on 12.07.24.
//

import Foundation
import Cocoa
import SwiftUI

class UpdateChecker {
    static let shared = UpdateChecker()
    
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
                
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
