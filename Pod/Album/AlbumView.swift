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

    private var title: String {
        switch GlobalState.shared.sourceFilter {
        case .spotify: return "Spotify"
        case .radio: return "Radio"
        case .local: return "Local"
        case .none: return "Albums"
        }
    }

    private var emptyStateIcon: String {
        if !GlobalState.shared.searchQuery.isEmpty { return "magnifyingglass" }
        switch GlobalState.shared.sourceFilter {
        case .spotify: return "music.note"
        case .radio: return "radio"
        case .local: return "folder"
        case .none: return "music.note.list"
        }
    }

    private var emptyStateTitle: String {
        if !GlobalState.shared.searchQuery.isEmpty { return "No results" }
        switch GlobalState.shared.sourceFilter {
        case .spotify: return "No Spotify content"
        case .radio: return "No radio stations"
        case .local: return "No local music"
        case .none: return "No items found"
        }
    }

    private var emptyStateSubtitle: String {
        if !GlobalState.shared.searchQuery.isEmpty { return "Try a different search" }
        switch GlobalState.shared.sourceFilter {
        case .spotify: return "Click to configure Spotify in Settings"
        case .radio: return "Click to add radio stations in Settings"
        case .local: return "Add music to your Music folder"
        case .none: return "Click to configure in Settings"
        }
    }

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

    private let albumSize: CGFloat = 140
    private let sideRotation: Double = 70
    private let sideSpacing: CGFloat = 45
    private let centerGap: CGFloat = 75

    private func coverFlowOffset(for index: Int) -> CGFloat {
        let diff = index - viewModel.activeIndex
        if diff == 0 { return 0 }
        let sign: CGFloat = diff > 0 ? 1 : -1
        return sign * (centerGap + CGFloat(abs(diff) - 1) * sideSpacing)
    }

    private func coverFlowRotation(for index: Int) -> Double {
        let diff = index - viewModel.activeIndex
        if diff == 0 { return 0 }
        return diff > 0 ? -sideRotation : sideRotation
    }

    private func coverFlowZIndex(for index: Int) -> Double {
        Double(viewModel.filteredAlbums.count - abs(index - viewModel.activeIndex))
    }

    private func coverFlowOpacity(for index: Int) -> Double {
        let dist = abs(index - viewModel.activeIndex)
        if dist == 0 { return 1.0 }
        return max(0.3, 1.0 - Double(dist) * 0.15)
    }

    @ViewBuilder
    private func albumArt(for index: Int) -> some View {
        let album = viewModel.filteredAlbums[index]
        if album.isRadioStation {
            RadioStationView(size: albumSize)
        } else if album.isSpotifyPlaylist || album.isSpotifyAlbum {
            AsyncSpotifyImage(imageUrl: album.spotifyImageUrl, size: albumSize)
        } else if let coverImage = album.coverImage {
            Image(nsImage: coverImage)
                .resizable()
                .frame(width: albumSize, height: albumSize)
                .cornerRadius(2)
        } else {
            Rectangle()
                .fill(Color.gray)
                .frame(width: albumSize, height: albumSize)
                .cornerRadius(2)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            MenuBar(title: title, isPlaying: GlobalState.shared.songViewModel.isPlaying)
            if !GlobalState.shared.searchQuery.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Text(GlobalState.shared.searchQuery)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.85))
            }
            if viewModel.filteredAlbums.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: emptyStateIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .foregroundColor(.gray)
                    Text(emptyStateTitle).bold()
                        .foregroundColor(.black)
                    Text(emptyStateSubtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }.frame(width: 220)
                Spacer()
            } else {
                ZStack {
                    ForEach(viewModel.filteredAlbums.indices, id: \.self) { index in
                        VStack(spacing: 6) {
                            albumArt(for: index)
                                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)

                            if index == viewModel.activeIndex {
                                Text(viewModel.filteredAlbums[index].name)
                                    .font(.system(size: 12, weight: .heavy))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.black)
                                    .frame(width: albumSize + 20)
                            }
                        }
                        .rotation3DEffect(
                            .degrees(coverFlowRotation(for: index)),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.5
                        )
                        .offset(x: coverFlowOffset(for: index))
                        .zIndex(coverFlowZIndex(for: index))
                        .opacity(coverFlowOpacity(for: index))
                        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: viewModel.activeIndex)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                viewModel.activeIndex = index
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
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

