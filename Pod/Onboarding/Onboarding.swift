//
//  Onboarding.swift
//  Pod
//
//  Created by Iskren Alexandrov on 8.07.24.
//

import Foundation
import SwiftUI

struct Onboarding: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var screens: [OnboardingScreenModel] = [
        OnboardingScreenModel(title: "Welcome to Pod", iconName: "appIcon"),
        OnboardingScreenModel(title: "Guide", iconName: "music.quarternote.3", heading: "Use the Music folder", description: "Paste your music into the Music folder on your Mac."),
        OnboardingScreenModel(title: "Guide", iconName: "hand.draw.fill", heading: "Click Hold Drag", description: "Click wheel is used by dragging in a circle"),
        OnboardingScreenModel(title: "Soon", iconName: "app.connected.to.app.below.fill", heading: "Connect your existing music", description: "Spotify and Apple Music integration"),
    ]
    
    var body: some View {
        ZStack {
            OnboardingScreen(screen: screens[viewModel.activeScreen], activeScreen: viewModel.activeScreen)
        }.padding()
    }
}

struct OnboardingScreen: View {
    var screen: OnboardingScreenModel
    var activeScreen: Int
    
    var body: some View {
        VStack () {
            Text(screen.title).font(.system(size: 20, weight: .bold, design: .default))
            Spacer()
            if(activeScreen == 0) {
                Image("appIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
            }
            
            HStack(spacing: 15) {
                Spacer(minLength: 10)
                Image(systemName: screen.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .foregroundColor(.pink)
                VStack (alignment: .leading, spacing: 2) {
                    Text(screen.heading ?? "").bold()
                    Text(screen.description ?? "")
                }
                Spacer(minLength: 10)
            }
            Spacer()
//            Button {
//               
//            } label: {
//                Text("Next")
//                    .frame(width: 240, height: 40)
//                    .background(Color.orange)
//                    .foregroundStyle(.white)
//                    .font(.system(size: 18, weight: .bold, design: .default))
//                    .cornerRadius(3)
//            }
//            .buttonStyle(PlainButtonStyle())
//            .shadow(radius: 0)
        }
    }
    
}
