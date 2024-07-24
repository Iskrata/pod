//
//  Contacts.swift
//  Pod
//
//  Created by Iskren Alexandrov on 24.07.24.
//

import SwiftUI

struct ContactUs: View {
    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                Button(action: {
                    let email = "mailto:iskren.alexandrov@gmail.com?subject=Discussion%20about%20Pod"
                    if let url = URL(string: email) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Label("Email", systemImage: "envelope")
                        .padding()
                }
                Button(action: {
                    let website = "https://x.com/iskrataa"
                    if let url = URL(string: website) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Label("X", systemImage: "x.circle")
                        .padding()
                }
            }
            
            
            Spacer()
        }
    }
}
