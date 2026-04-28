//
//  ContactUs.swift
//  Pod
//

import SwiftUI

struct ContactUs: View {
    var body: some View {
        CenteredSettingsContent {
            VStack(spacing: 20) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.accentColor)

                Text("Get in Touch")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Have questions or feedback?\nWe'd love to hear from you!")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    ActionCard(icon: "envelope.fill", title: "Email") {
                        openURL("mailto:support@desktopipod.com?subject=Pod%20Feedback")
                    }
                    ActionCard(icon: "bird.fill", title: "Twitter") {
                        openURL("https://x.com/iskrataa")
                    }
                }
            }
        }
    }

    private func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}
