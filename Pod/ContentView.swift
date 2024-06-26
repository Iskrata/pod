//
//  ContentView.swift
//  Pod
//
//  Created by Iskren Alexandrov on 22.06.24.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("fontSize") var fontSize = 13.0
    @StateObject private var songView = SongViewModel(loadUrl: "/Users/iskrenalexandrov/Music/IGOR")
    
    var body: some View {
        ZStack {
//            Color.blue
            VStack {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 320, height: 240)
                    .overlay(VStack {
                        SongView(viewModel: songView)
                    })
                    .border(Color.black, width: 4)
                    .shadow(radius: 10)
                    .cornerRadius(5)
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(.wheel)
                        .frame(width: 200, height: 200)
                    
                    VStack {
                        Button(action: {
                        }) {
                            Text("MENU")
                                .foregroundColor(.white)
                                .padding()
                        }
                        
                        Spacer()
                        
                        HStack (spacing: 5) {
                            Button(action: {
                                songView.prevSong()
                            }) {
                                Image(systemName: "backward.fill")
                                    .foregroundColor(.white)
                                    .padding()
                            }
                            
                            
                            Button(action: {
                                // Center button action
                            }) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 44, height: 44)
                            }
                            
                            Button(action: {
                                songView.nextSong()
                            }) {
                                Image(systemName: "forward.fill")
                                    .foregroundColor(.white)
                                    .padding()
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            songView.playPause()
                        }) {
                            Image(systemName: "playpause.fill")
                                .foregroundColor(.white)
                                .padding()
                        }
                    }
                    .padding(30)
                }
            }
            .padding()
        }
    }
    
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
