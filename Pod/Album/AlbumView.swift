//
//  AlbumsView.swift
//  Pod
//
//  Created by Iskren Alexandrov on 29.06.24.
//

import SwiftUI
import AVFoundation

struct AlbumsView: View {
    @ObservedObject var viewModel: AlbumViewModel
    @State private var isAnimating = false
    
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

    func scale(for innerFrame: CGRect, in outerFrame: CGRect) -> CGFloat {
        let scale = max(0.8, min(1, 1 - abs(innerFrame.midX - outerFrame.midX) / outerFrame.width))
        return scale
    }

    var body: some View {
        VStack {
            GeometryReader { outerGeometry in
                VStack {
                    Spacer()
                    if viewModel.albums.count == 0 {
                        HStack {
                            Spacer()
                            VStack (alignment: .center, spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 30, height: 30)
                                Text("No music found.").bold()
                                Text("Move some mp3's into the Music folder on your Mac").font(.system(size: 10, design: .default))
                            }.frame(width: 150)
                            Spacer()
                        }
                    }
                    else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach(viewModel.albums.indices, id: \.self) { index in
                                    GeometryReader { innerGeometry in
                                        VStack(spacing: 10) {
                                            if index < viewModel.albums.count {
                                                ZStack(alignment: .bottomTrailing) {
                                                    if viewModel.albums[index].isRadioStation {
                                                        RadioStationView(size: 150)
                                                    } else if viewModel.albums[index].isSpotifyPlaylist || viewModel.albums[index].isSpotifyAlbum {
                                                        AsyncSpotifyImage(
                                                            imageUrl: viewModel.albums[index].spotifyImageUrl,
                                                            size: 150
                                                        )
                                                    } else if let coverImage = viewModel.albums[index].coverImage {
                                                        Image(nsImage: coverImage)
                                                            .resizable()
                                                            .frame(width: 150, height: 150)
                                                            .cornerRadius(2)
                                                    } else {
                                                        Rectangle()
                                                            .fill(Color.gray)
                                                            .frame(width: 150, height: 150)
                                                            .cornerRadius(2)
                                                    }
                                                }
                                                
                                                Text(viewModel.albums[index].name)
                                                    .font(.system(size: 13, weight: .heavy))
                                                    .lineLimit(2)
                                                    .multilineTextAlignment(.center)
                                                    .foregroundColor(.black)
                                            }
                                        }
                                        .scaleEffect(self.scale(for: innerGeometry.frame(in: .global), in: outerGeometry.frame(in: .global)))
                                        .onTapGesture {
                                            withAnimation {
                                                viewModel.activeIndex = index
                                            }
                                        }
                                    }
                                    .frame(width: 150, height: 200)
                                }
                            }
                            .padding(.horizontal, (outerGeometry.size.width - 150) / 2)
                            .offset(x: viewModel.scrollOffset)
                        }
                    }
                    Spacer()
                }
                .onChange(of: viewModel.activeIndex) { newIndex in
                    withAnimation {
                        updateScrollOffset(for: newIndex, in: outerGeometry.size)
                    }
                }
            }
        }
    }

    /// Updates the scrollOffset based on the active Index, to center the album.
    private func updateScrollOffset(for index: Int, in size: CGSize) {
        let albumWidthWithSpacing = 170.0
        viewModel.scrollOffset = -(CGFloat(index) * albumWidthWithSpacing)
    }
}

struct AsyncSpotifyImage: View {
    let imageUrl: String?
    let size: CGFloat

    var body: some View {
        AsyncImage(url: URL(string: imageUrl ?? "")) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .cornerRadius(2)
            case .failure, .empty:
                SpotifyPlaceholderView(size: size)
            @unknown default:
                SpotifyPlaceholderView(size: size)
            }
        }
        .frame(width: size, height: size)
    }
}

struct SpotifyPlaceholderView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
                .frame(width: size, height: size)
                .cornerRadius(2)
            Image(systemName: "music.note")
                .font(.system(size: size * 0.3))
                .foregroundColor(.green)
        }
    }
}
