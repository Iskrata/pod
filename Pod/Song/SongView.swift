//
//  SongView.swift
//  Pod
//
//  Created by Iskren Alexandrov on 23.06.24.
//

import Foundation
import SwiftUI

struct SongView: View {
    @ObservedObject var viewModel: SongViewModel
    @StateObject private var settings = GlobalState.shared
    
    var body: some View {
        VStack {
            MenuBar(isPlaying: viewModel.isPlaying)
            
            HStack(spacing: 20) {
                VStack {
                    if viewModel.isRadioStation {
                        Image(systemName: "radio")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .modifier(PerspectiveTransformEffect())
                    } else if let coverImage = viewModel.songs[viewModel.currentSong].coverImage {
                        Image(nsImage: coverImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .modifier(PerspectiveTransformEffect())
                    } else {
                        Rectangle()
                            .aspectRatio(contentMode: .fit)
                    }
                }
                
                if viewModel.isRadioStation {
                    SongInfo(
                        title: viewModel.currentRadioName,
                        artist: "Live Radio",
                        album: nil
                    )
                } else {
                    SongInfo(
                        title: viewModel.getCurrentSongTitle(),
                        artist: viewModel.getCurrentSongArtist(),
                        album: viewModel.getCurrentSongAlbum()
                    )
                }
                Spacer()
            }.padding()
            
            if !viewModel.isRadioStation {
                SongProgress(
                    currentTime: viewModel.formattedCurrentTime,
                    duration: viewModel.formattedDuration,
                    viewModel: viewModel
                )
            }
        }.onAppear(perform: {
            if !viewModel.isRadioStation {
                viewModel.songs = loadAudioFiles(from: settings.selectedAlbumDir)
                viewModel.loadAudioFile(viewModel.songs[viewModel.currentSong].pathToAudioFile)
                viewModel.playPauseClick()
            }
        })
    }
}

struct PerspectiveTransformEffect: ViewModifier {
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(15),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                anchorZ: 0,
                perspective: 0.5
            )
    }
}

struct ReflectionView: View {
    let imageName: String
    
    var body: some View {
        VStack {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(x: 1, y: -1, anchor: .center)
                .opacity(0.5)
                .mask(LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.6), Color.black.opacity(0)]), startPoint: .top, endPoint: .bottom))
                .frame(height: 50) // Adjust the height as needed
        }
        .frame(width: 100) // Adjust the width as needed
        .clipped()
    }
}

struct SongProgress: View {
    var currentTime: String
    var duration: String
    var viewModel: SongViewModel
    
    var body: some View {
        HStack {
            Text(currentTime)
                .foregroundColor(.black)
                .fontWeight(/*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
                .frame(width: 40, alignment: .leading)
            
            ProgressView(value:viewModel.currentTime / viewModel.duration)
                .border(Color.gray, width: /*@START_MENU_TOKEN@*/1/*@END_MENU_TOKEN@*/)
                .cornerRadius(/*@START_MENU_TOKEN@*/3.0/*@END_MENU_TOKEN@*/)
            
            Text(duration)
                .foregroundColor(.black)
                .fontWeight(/*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
                .frame(width: 40, alignment: .trailing)
            
        }.padding()
    }
}

struct SongInfo: View {
    var title: String
    var artist: String?
    var album: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .foregroundColor(.black)
                .font(.system(size: 16, weight: .bold, design: .default))
            Text(artist ?? "No Artist found")
                .foregroundColor(.infoGray)
                .font(.system(size: 11, weight: .bold, design: .default))
            Text(album ?? "No Album found")
                .foregroundColor(.infoGray)
                .font(.system(size: 11, weight: .bold, design: .default))
            Spacer()
        }
    }
}

struct MenuBar: View {
    var isPlaying: Bool
    
    var body: some View {
        HStack {
            Text("Now Playing")
                .foregroundColor(.black)
                .fontWeight(/*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
            
            Spacer()
            Image(systemName:
                    isPlaying ? "pause.fill" : "play.fill")
            .foregroundColor(.blue)
            Image(systemName: "battery.100percent")
                .foregroundColor(.green)
            
        }
        .padding(7)
        .background(.menuBarGray)
        .border(/*@START_MENU_TOKEN@*/Color.black/*@END_MENU_TOKEN@*/, width: 1)
        .shadow(radius: /*@START_MENU_TOKEN@*/10/*@END_MENU_TOKEN@*/)
    }
}
