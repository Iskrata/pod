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
    @StateObject private var radioViewModel = RadioSettingsViewModel()

    var screens: [OnboardingScreenModel] = [
        OnboardingScreenModel(title: "Welcome to Pod", iconName: "appIcon"),
        OnboardingScreenModel(title: "Guide", iconName: "music.quarternote.3", heading: "Use the Music folder", description: "Paste your music into the Music folder on your Mac."),
        OnboardingScreenModel(title: "Guide", iconName: "hand.draw.fill", heading: "Click Hold Drag", description: "Click wheel is used by dragging in a circle"),
        OnboardingScreenModel(title: "Radio", iconName: "radio", heading: "Internet Radio", description: "Add your favorite radio stations", isRadioSetup: true),
        OnboardingScreenModel(title: "Soon", iconName: "app.connected.to.app.below.fill", heading: "Connect your existing music", description: "Spotify and Apple Music integration"),
    ]
    
    var body: some View {
        ZStack {
            if screens[viewModel.activeScreen].isRadioSetup {
                RadioSetupScreen(radioViewModel: radioViewModel)
            } else {
                OnboardingScreen(screen: screens[viewModel.activeScreen], activeScreen: viewModel.activeScreen)
            }
        }.padding()
    }
}

struct OnboardingScreen: View {
    var screen: OnboardingScreenModel
    var activeScreen: Int
    
    var body: some View {
        VStack () {
            Text(screen.title).font(.system(size: 20, weight: .bold, design: .default))
                .foregroundStyle(.black)
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
                    .foregroundColor(.accentColor)
                VStack (alignment: .leading, spacing: 2) {
                    Text(screen.heading ?? "")
                        .foregroundStyle(.black)
                        .bold()
                    
                    Text(screen.description ?? "")
                        .foregroundStyle(.black)
                }
                Spacer(minLength: 10)
            }
            Spacer()
        }
    }
    
}

struct RadioSetupScreen: View {
    @ObservedObject var radioViewModel: RadioSettingsViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Radio Stations")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black)
            
//            Text("Search and add your favorite radio stations")
//                .foregroundColor(.secondary)
            
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search radio stations", text: $radioViewModel.searchText)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
            
            if radioViewModel.isSearching {
                ProgressView()
            } else if let error = radioViewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            } else if !radioViewModel.searchText.isEmpty {
                List {
                    ForEach(radioViewModel.searchResults) { station in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(station.name)
                                    .foregroundColor(.primary)
                                Text(station.country)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                radioViewModel.toggleFavorite(station)
                            }) {
                                Image(systemName: radioViewModel.isFavorite(station) ? "heart.fill" : "heart")
                                    .foregroundColor(radioViewModel.isFavorite(station) ? .red : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .frame(height: 120)
            } else {
                Text("Search for your favorite radio stations")
                    .foregroundColor(.secondary)
                    .padding()
            }
            
//            if !radioViewModel.favoriteStations.isEmpty {
//                VStack(alignment: .leading, spacing: 8) {
//                    Text("Your Favorites")
//                        .font(.headline)
//                    
//                    ForEach(radioViewModel.favoriteStations) { station in
//                        HStack {
//                            Text(station.name)
//                            Spacer()
//                            Button(action: {
//                                radioViewModel.toggleFavorite(station)
//                            }) {
//                                Image(systemName: "heart.fill")
//                                    .foregroundColor(.red)
//                            }
//                            .buttonStyle(.plain)
//                        }
//                        .padding(.vertical, 2)
//                    }
//                }
//                .padding()
//                .background(Color.secondary.opacity(0.1))
//                .cornerRadius(8)
//            }
            
            Text("You can always add more stations later in Settings")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top)
        }
    }
}
