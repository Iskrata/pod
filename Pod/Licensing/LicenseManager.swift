import Foundation
import TelemetryDeck

class LicenseManager: ObservableObject {
    static let shared = LicenseManager()
    
    @Published var isLicensed: Bool = false
    @Published var isTrialActive: Bool = false
    @Published var trialDaysRemaining: Int = 0
    @Published var showLicenseWindow: Bool = false
    @Published var activationError: String? = nil
    
    private let licenseKey = "app.licensed"
    private let licenseDataKey = "app.license.data"
    private let trialStartKey = "app.trial.start"
    private let trialDuration = 7
    private let hasUsedTrialKey = "app.trial.used"
    private let apiKey = "creem_1UNFYIw2KuDzgaokaKztpN"
    private let creemEndpoint = "https://api.creem.io/v1/licenses/activate"
    
    struct CreemLicenseInstance: Codable {
        let id: String
        let object: String
        let name: String
        let status: String
        let createdAt: String
        
        enum CodingKeys: String, CodingKey {
            case id, object, name, status
            case createdAt = "created_at"
        }
    }
    
    struct CreemLicenseResponse: Codable {
        let id: String
        let mode: String
        let object: String
        let status: String
        let key: String
        let activation: Int
        let activationLimit: Int
        let expiresAt: String?
        let createdAt: String
        let instance: CreemLicenseInstance
        
        enum CodingKeys: String, CodingKey {
            case id, mode, object, status, key, activation, instance
            case activationLimit = "activation_limit"
            case expiresAt = "expires_at"
            case createdAt = "created_at"
        }
    }
    
    struct CreemErrorResponse: Codable {
        let traceId: String
        let status: Int
        let error: String
        let message: String
        let timestamp: Int64
        
        enum CodingKeys: String, CodingKey {
            case traceId = "trace_id"
            case status, error, message, timestamp
        }
    }
    
    private init() {
        // Try to restore license data first
        if let savedLicenseData = UserDefaults.standard.data(forKey: licenseDataKey),
           let licenseResponse = try? JSONDecoder().decode(CreemLicenseResponse.self, from: savedLicenseData) {
            self.isLicensed = licenseResponse.status == "active"
        } else {
            self.isLicensed = false
        }
        
        // Handle trial period
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
            DispatchQueue.main.async {
                LicenseWindowManager.shared.showLicenseWindow()
            }
        }
        return canUse
    }
    
    func activate(with licenseKey: String) async -> Bool {
        guard let deviceName = Host.current().localizedName else {
            activationError = "Could not determine device name"
            return false
        }
        
        let body = [
            "key": licenseKey,
            "instance_name": deviceName
        ]
        
        guard let url = URL(string: creemEndpoint) else {
            activationError = "Invalid API endpoint"
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                activationError = "Invalid server response"
                return false
            }
            
            // Try to decode error response first for any non-200 status
            if httpResponse.statusCode != 200 {
                do {
                    let errorResponse = try JSONDecoder().decode(CreemErrorResponse.self, from: data)
                    activationError = errorResponse.message.capitalized
                    return false
                } catch {
                    // If we can't decode the error response, use a generic message
                    activationError = "Invalid license key"
                    return false
                }
            }
            
            // Try to decode the success response
            do {
                let licenseResponse = try JSONDecoder().decode(CreemLicenseResponse.self, from: data)
                
                if licenseResponse.status == "active" {
                    isLicensed = true
                    // Store the complete license response
                    UserDefaults.standard.set(data, forKey: licenseDataKey)
                    TelemetryDeck.signal("License.activated")
                    await MainActor.run {
                        LicenseWindowManager.shared.closeLicenseWindow()
                    }
                    activationError = nil
                    return true
                }
                
                activationError = "License is not active"
                return false
            } catch {
                print("Failed to decode success response: \(error)")
                activationError = "Invalid license key"
                return false
            }
        } catch {
            print("Network error: \(error)")
            activationError = "Failed to connect to license server"
            return false
        }
    }
    
    func deactivate() {
        isLicensed = false
        UserDefaults.standard.removeObject(forKey: licenseDataKey)
        TelemetryDeck.signal("License.deactivated")
    }
    
    func startTrial() {
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
    
    #if DEBUG
    func resetTrialStatus() {
        UserDefaults.standard.removeObject(forKey: trialStartKey)
        UserDefaults.standard.removeObject(forKey: hasUsedTrialKey)
        checkTrialStatus()
    }
    #endif
} 