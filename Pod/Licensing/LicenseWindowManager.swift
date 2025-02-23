import SwiftUI
import AppKit

class LicenseWindowManager: NSObject {
    static let shared = LicenseWindowManager()
    private var licenseWindow: NSWindow?
    private var windowDelegate: LicenseWindowDelegate?
    private var hostingView: NSHostingView<LicenseActivationView>?
    
    func showLicenseWindow() {
        if let existingWindow = licenseWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        windowDelegate = LicenseWindowDelegate()
        window.delegate = windowDelegate
        
        window.title = "Activate Pod"
        window.center()
        
        let contentView = LicenseActivationView()
        hostingView = NSHostingView(rootView: contentView)
        window.contentView = hostingView
        
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        licenseWindow = window
    }
    
    func closeLicenseWindow() {
        licenseWindow?.orderOut(nil)
        licenseWindow = nil
        hostingView = nil
        windowDelegate = nil
    }
    
    deinit {
        closeLicenseWindow()
    }
}

@objc class LicenseWindowDelegate: NSObject, NSWindowDelegate {
    @objc func windowShouldClose(_ sender: NSWindow) -> Bool {
        let licenseManager = LicenseManager.shared
        if !licenseManager.isLicensed && !licenseManager.isTrialActive {
            let alert = NSAlert()
            alert.messageText = "License Required"
            alert.informativeText = "You need to activate Pod or start a trial to continue using the app."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Continue Activation")
            alert.addButton(withTitle: "Quit")
            
            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                DispatchQueue.main.async {
                    NSApplication.shared.terminate(nil)
                }
            }
            return false
        }
        return true
    }
} 