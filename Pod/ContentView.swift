//
//  ContentView.swift
//  Pod
//
//  Created by Iskren Alexandrov on 22.06.24.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @AppStorage("fontSize") var fontSize = 13.0
    
    @StateObject private var globalState = GlobalState.shared
    
    private var views: [Screen: any ProtocolView] = [
        .onboarding: OnboardingViewModel(),
        .song: GlobalState.shared.songViewModel,
        .albums: AlbumViewModel(),
    ]
    
    var body: some View {
        ZStack {
            VStack {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 320, height: 240)
                    .overlay(ZStack {
                        if let currentView = views[globalState.activeView]?.view {
                            AnyView(currentView)
                        } else {
                            Text("No View Available")
                        }
                    })
                    .border(Color.black, width: 4)
                    .shadow(radius: 10)
                    .cornerRadius(5)
                
                Spacer()
                
                ClickWheel(views: views)
            }
            .padding()
        }.background(.base)
    }
    
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
