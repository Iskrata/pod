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
            MenuBar(title: "Now Playing", isPlaying: viewModel.isPlaying)
            
            HStack(spacing: 20) {
                VStack {
                    if viewModel.isSpotifyPlayback {
                        AsyncSpotifyImage(
                            imageUrl: viewModel.currentSpotifyTrack?.albumImageUrl ?? viewModel.currentSpotifyImageUrl ?? "",
                            size: 100
                        )
                        .modifier(PerspectiveTransformEffect())
                    } else if viewModel.isRadioStation {
                        RadioStationView(size: 100)
                            .modifier(PerspectiveTransformEffect())
                    } else if !viewModel.songs.isEmpty,
                              let coverImage = viewModel.songs[viewModel.currentSong].coverImage {
                        Image(nsImage: coverImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .modifier(PerspectiveTransformEffect())
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(contentMode: .fit)
                    }
                }

                if viewModel.isSpotifyPlayback {
                    if let track = viewModel.currentSpotifyTrack {
                        SongInfo(
                            title: track.name,
                            artist: track.artist,
                            album: track.album
                        )
                    } else {
                        SongInfo(
                            title: viewModel.currentSpotifyPlaylistName,
                            artist: "Spotify",
                            album: nil
                        )
                    }
                } else if viewModel.isRadioStation {
                    SongInfo(
                        title: viewModel.currentRadioName,
                        artist: "Live Radio",
                        album: nil
                    )
                } else if !viewModel.songs.isEmpty {
                    SongInfo(
                        title: viewModel.getCurrentSongTitle(),
                        artist: viewModel.getCurrentSongArtist(),
                        album: viewModel.getCurrentSongAlbum()
                    )
                } else {
                    SongInfo(title: "No song", artist: nil, album: nil)
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
        }.onAppear {
            if !viewModel.isRadioStation && !viewModel.isSpotifyPlayback {
                viewModel.songs = loadAudioFiles(from: settings.selectedAlbumDir)
                if !viewModel.songs.isEmpty {
                    viewModel.loadAudioFile(viewModel.songs[viewModel.currentSong].pathToAudioFile)
                    viewModel.playPauseClick()
                }
            }
        }
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
            
            ProgressView(value: viewModel.duration > 0 ? viewModel.currentTime / viewModel.duration : 0)
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

struct RadioStationView: View {
    @State private var isAnimating = false
    var size: CGFloat
    
    private func animatedBars() -> some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor.opacity(0.8))
                    .frame(width: 3, height: 16)
                    .scaleEffect(y: isAnimating ? [0.7, 1.0, 0.85][index] : 0.3)
                    .animation(
                        Animation.easeInOut(duration: [0.6, 0.5, 0.7][index])
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: isAnimating
                    )
            }
        }
        .frame(width: 15, height: 16)
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Rectangle()
                .fill(.white)
                .border(Color.accentColor.opacity(0.8), width: 2)
                .frame(width: size, height: size)
                .cornerRadius(2)
                .overlay(
                    Text("RADIO")
                        .font(.system(size: size/5, weight: .bold))
                        .foregroundColor(Color.accentColor.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.1)
                        .frame(width: size, height: size)
                )
                .overlay(
                    animatedBars()
                        .padding(10),
                    alignment: .bottomTrailing
                )
        }
        .onAppear {
            isAnimating = true
        }
    }
}
