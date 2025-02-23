import SwiftUI

struct LicenseActivationView: View {
    @StateObject private var licenseManager = LicenseManager.shared
    @State private var licenseWords: [String] = Array(repeating: "", count: 5)
    @State private var showError: Bool = false
    @AppStorage("app.trial.used") private var hasUsedTrial: Bool = false
    
    func handlePaste(_ index: Int, text: String) {
        // Split pasted text by spaces and clean up
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: " ")
            .prefix(5) // Take only first 5 words
        
        // If we have multiple words, populate all fields
        if words.count > 1 {
            for (i, word) in words.enumerated() {
                licenseWords[i] = word
            }
        } else {
            // Single word, just update the current field
            licenseWords[index] = text
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                Image("appIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Activate Pod")
                        .font(.title)
                    
                    if licenseManager.isTrialActive {
                        Text("\(licenseManager.trialDaysRemaining) days remaining in trial")
                            .foregroundColor(.secondary)
                    } else {
                        Text("Trial period has expired")
                            .foregroundColor(.red)
                    }
                    Link("Purchase License", destination: URL(string: "https://www.desktopipod.com")!)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                Spacer()
                
                #if DEBUG
                Button("Expire Trial") {
                    // Set trial start date to 8 days ago
                    let expiredDate = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
                    UserDefaults.standard.set(expiredDate, forKey: "app.trial.start")
                    // Force refresh license manager
                    licenseManager.checkTrialStatus()
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                #endif
            }
            
            VStack(spacing: 16) {
                Text("Enter your license:")
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(0..<5) { index in
                        TextField("Secret \(index + 1)", text: $licenseWords[index])
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 100)
                            .onChange(of: licenseWords[index]) { newValue in
                                handlePaste(index, text: newValue)
                            }
                    }
                }
            }
            
            Button("Activate") {
                if !licenseManager.activate(with: licenseWords) {
                    showError = true
                }
            }
            
            if showError {
                Text("Invalid license words")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            if !licenseManager.isTrialActive && !licenseManager.isLicensed && !hasUsedTrial {
                Button("Start 7-Day Trial") {
                    licenseManager.startTrial()
                    LicenseWindowManager.shared.closeLicenseWindow()
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            } else {
                Button("Get License") {
                    NSWorkspace.shared.open(URL(string: "https://www.desktopipod.com")!)
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            }
      
        }
        .padding()
        .frame(width: 600, height: 300)
    }
} 

#Preview {
    LicenseActivationView();
}
