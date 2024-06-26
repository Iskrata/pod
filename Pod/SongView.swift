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
    
    var body: some View {
        Text(viewModel.audioPlayerViewModel.isPlaying ? "1" : "2").foregroundStyle(.black)
        MenuBar(isPlaying: viewModel.audioPlayerViewModel.isPlaying)
        
        HStack(spacing: 20) {
            Image("tyler-the-creator-album")
                .resizable()
                .aspectRatio(contentMode: .fit)
            SongInfo(title: viewModel.getCurrentSongTitle(), artist: viewModel.getCurrentSongArtist(), album: viewModel.getCurrentSongAlbum())
            Spacer()
        }.padding()
        
        SongProgress(currentTime: viewModel.audioPlayerViewModel.formattedCurrentTime, duration: viewModel.audioPlayerViewModel.formattedDuration, audioViewModel: viewModel.audioPlayerViewModel)
    }
}

struct SongProgress: View {
    var currentTime: String
    var duration: String
    var audioViewModel: AudioPlayerViewModel
    
    var body: some View {
        HStack {
            Text(currentTime)
                .foregroundColor(.black)
                .fontWeight(/*@START_MENU_TOKEN@*/.bold/*@END_MENU_TOKEN@*/)
                .frame(width: 40, alignment: .leading)
            
            ProgressView(value:audioViewModel.currentTime / audioViewModel.duration)
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

