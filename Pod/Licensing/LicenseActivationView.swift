import SwiftUI

struct LicenseActivationView: View {
    @StateObject private var licenseManager = LicenseManager.shared
    @State private var licenseKey: String = ""
    @State private var isActivating: Bool = false
    @AppStorage("app.trial.used") private var hasUsedTrial: Bool = false
    
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
                    let expiredDate = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
                    UserDefaults.standard.set(expiredDate, forKey: "app.trial.start")
                    licenseManager.checkTrialStatus()
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                #endif
            }
            
            VStack(spacing: 16) {
                Text("Enter your license key:")
                    .foregroundColor(.secondary)
                
                TextField("License Key", text: $licenseKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 400)
            }
            
            Button(action: {
                Task {
                    isActivating = true
                    
                    if await !licenseManager.activate(with: licenseKey) {
                        // Error will be shown through licenseManager.activationError
                    }
                    
                    isActivating = false
                }
            }) {
                if isActivating {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.8)
                } else {
                    Text("Activate")
                }
            }
            .disabled(licenseKey.isEmpty || isActivating)
            
            if let error = licenseManager.activationError {
                Text(error)
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
    LicenseActivationView()
}
