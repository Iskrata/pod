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
                        .overlay(VStack {
                            Button(action: {
                            }) {
                                VStack {
                                    Image("menu")
                                        .resizable()
                                        .scaledToFit()
                                    
                                    Spacer()
                                }
                                
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(width: 40.0, height: 40.0)
                                                        
                            HStack (spacing: 5) {
                                Spacer()
                                
                                Button(action: {
                                    songView.prevSong()
                                }) {
                                    HStack(spacing: 0) {
                                        Rectangle()
                                            .foregroundColor(.wheelButton)
                                            .frame(width: 3, height: 15)
                                        Image("left")
                                        Image("left")
                                    }
                                    
                                }
                                .buttonStyle(PlainButtonStyle())
                                .frame(width: 40.0, height: 40.0)

                                Spacer()
                                
                                Button(action: {}) {
                                    Circle()
                                        .fill(.base)
                                        .frame(width: 80, height: 80)
                                }
                                .buttonStyle(PlainButtonStyle())

                                Spacer()
                                
                                Button(action: {
                                    songView.nextSong()
                                }) {
                                    HStack(spacing: 0) {
                                        Image("right")
                                        Image("right")
                                        Rectangle()
                                            .foregroundColor(.wheelButton)
                                            .frame(width: 3, height: 15)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .frame(width: 40.0, height: 40.0)

                                Spacer()
                            }
                            
                            
                            Button(action: {
                                songView.playOrPause()
                            }) {
                                VStack {
                                    Spacer()
                                    HStack(spacing: 5) {
                                        Image("right")

                                        Rectangle()
                                            .foregroundColor(.wheelButton)
                                            .frame(width: 3, height: 15)
                                        Rectangle()
                                            .foregroundColor(.wheelButton)
                                            .frame(width: 3, height: 15)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(width: 40.0, height: 40.0)

                        }.padding(12)).padding(30)
                }
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
