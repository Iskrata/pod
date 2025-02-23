import Foundation
import TelemetryDeck
import CryptoKit

class LicenseManager: ObservableObject {
    static let shared = LicenseManager()
    
    @Published var isLicensed: Bool = false
    @Published var isTrialActive: Bool = false
    @Published var trialDaysRemaining: Int = 0
    @Published var showLicenseWindow: Bool = false
    
    private let licenseKey = "app.licensed"
    private let trialStartKey = "app.trial.start"
    private let trialDuration = 7 // days
    private let hasUsedTrialKey = "app.trial.used"
    
    // Word list for license validation
    private let validWords = [
        "apple", "banana", "cherry", "dragon", "elephant",
        "forest", "guitar", "hammer", "island", "jungle",
        "kettle", "lemon", "mango", "needle", "orange",
        "pencil", "quartz", "rabbit", "sunset", "turtle"
    ]
    
    private let salt = "Pod2024" // Should be stored securely in production
    
    private init() {
        // Check for license hash instead of boolean
        self.isLicensed = UserDefaults.standard.string(forKey: licenseKey) != nil
        
        // Then handle trial period
        if let trialStartDate = UserDefaults.standard.object(forKey: trialStartKey) as? Date {
            let daysSinceTrialStart = Calendar.current.dateComponents([.day], from: trialStartDate, to: Date()).day ?? 0
            self.trialDaysRemaining = max(0, trialDuration - daysSinceTrialStart)
            self.isTrialActive = self.trialDaysRemaining > 0
        } else {
            self.trialDaysRemaining = trialDuration
            self.isTrialActive = !UserDefaults.standard.bool(forKey: hasUsedTrialKey)
        }
    }
    
    var canUseApp: Bool {
        let canUse = isLicensed || isTrialActive
        if !canUse && !showLicenseWindow {
            showLicenseWindow = true
            // Use async to avoid potential UI updates during initialization
            DispatchQueue.main.async {
                LicenseWindowManager.shared.showLicenseWindow()
            }
        }
        return canUse
    }
    
    func activate(with words: [String]) -> Bool {
        guard words.count == 5 else { return false }
        
        // Convert words to lowercase and join them
        let normalizedKey = words.map { $0.lowercased() }.joined()
        
        // Create a hash of the key with salt
        let keyData = Data((normalizedKey + salt).utf8)
        let hash = SHA256.hash(data: keyData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        // In production, you would validate this hash against a server
        // For now, we'll validate against our valid words list
        let isValid = words.allSatisfy { validWords.contains($0.lowercased()) }
        
        if isValid {
            isLicensed = true
            UserDefaults.standard.set(hashString, forKey: licenseKey)
            TelemetryDeck.signal("License.activated")
            LicenseWindowManager.shared.closeLicenseWindow()
        }
        
        return isValid
    }
    
    func deactivate() {
        isLicensed = false
        UserDefaults.standard.removeObject(forKey: licenseKey)
        TelemetryDeck.signal("License.deactivated")
    }
    
    func startTrial() {
        // Check if trial was already used
        if UserDefaults.standard.bool(forKey: hasUsedTrialKey) {
            return
        }
        
        UserDefaults.standard.set(Date(), forKey: trialStartKey)
        UserDefaults.standard.set(true, forKey: hasUsedTrialKey)
        isTrialActive = true
        trialDaysRemaining = trialDuration
        TelemetryDeck.signal("Trial.started")
    }
    
    func checkTrialStatus() {
        if let trialStartDate = UserDefaults.standard.object(forKey: trialStartKey) as? Date {
            let daysSinceTrialStart = Calendar.current.dateComponents([.day], from: trialStartDate, to: Date()).day ?? 0
            self.trialDaysRemaining = max(0, trialDuration - daysSinceTrialStart)
            self.isTrialActive = self.trialDaysRemaining > 0
        }
    }
    
    // For debugging purposes, add this method
    #if DEBUG
    func resetTrialStatus() {
        UserDefaults.standard.removeObject(forKey: trialStartKey)
        UserDefaults.standard.removeObject(forKey: hasUsedTrialKey)
        checkTrialStatus()
    }
    #endif
} 