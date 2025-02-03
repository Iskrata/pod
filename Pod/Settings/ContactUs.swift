//
//  Contacts.swift
//  Pod
//
//  Created by Iskren Alexandrov on 24.07.24.
//

import SwiftUI

struct ContactUs: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("Get in Touch")
                .font(.title2)
                .bold()
            
            Text("Have questions or feedback? We'd love to hear from you!")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Button(action: {
                    if let url = URL(string: "mailto:iskren.alexandrov@gmail.com?subject=Discussion%20about%20Pod") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "envelope.fill")
                            .font(.title2)
                        Text("Email")
                            .font(.caption)
                    }
                    .frame(width: 80, height: 80)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    if let url = URL(string: "https://x.com/iskrataa") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "x.circle.fill")
                            .font(.title2)
                        Text("Twitter")
                            .font(.caption)
                    }
                    .frame(width: 80, height: 80)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
