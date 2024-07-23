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
                                                if let coverImage = viewModel.albums[index].coverImage {
                                                    Image(nsImage:coverImage)
                                                        .resizable()
                                                        .frame(width: 150, height: 150)
                                                        .cornerRadius(2)
                                                } else {
                                                    Rectangle()
                                                        .fill(Color.gray)
                                                        .frame(width: 150, height: 150)
                                                        .cornerRadius(2)
                                                }
                                                Text(viewModel.albums[index].name)
                                                    .font(.system(size: 13, weight: .heavy))
                                                    .lineLimit(2)
                                                    .multilineTextAlignment(.center)
                                                    .foregroundColor(.black)
                                            }
                                        }
                                        .scaleEffect(viewModel.scale(for: innerGeometry.frame(in: .global), in: outerGeometry.frame(in: .global)))
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
                    // Update scroll offset when activeIndex changes
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
