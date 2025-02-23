import SwiftUI

struct LicenseSetupScreen: View {
    @StateObject private var licenseManager = LicenseManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Start Your Pod Journey")
                .font(.title2)
                .bold()
            
            VStack(spacing: 10) {
                Text("\(licenseManager.trialDaysRemaining) Days Free Trial")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                Text("No credit card required")
                    .foregroundColor(.secondary)
            }
            
            Button("Have a License Key?") {
                LicenseWindowManager.shared.showLicenseWindow()
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)
        }
        .padding()
    }
} 