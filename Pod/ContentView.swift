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
    
    private var views: [any ProtocolView] {[albumView, songView, onboardingView]}
    
    @StateObject private var songView = SongViewModel()
    @StateObject private var albumView = AlbumViewModel()
    @StateObject private var onboardingView = OnboardingViewModel()
            
    var body: some View {
        ZStack {
            VStack {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 320, height: 240)
                    .overlay(ZStack {
                        //                        Text("\(GlobalState.shared.activeView)").foregroundStyle(.red).zIndex(100)
                            switch GlobalState.shared.activeView {
                            case 0:
                                AlbumsView(viewModel: views[0] as! AlbumViewModel)
                            case 1:
                                SongView(viewModel: views[1] as! SongViewModel)
                            case 2:
                                Onboarding(viewModel: views[2] as! OnboardingViewModel)
                            default:
                                AlbumsView(viewModel: views[0] as! AlbumViewModel)
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
