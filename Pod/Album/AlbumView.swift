//
//  AlbumsView.swift
//  Pod
//
//  Created by Iskren Alexandrov on 29.06.24.
//

import SwiftUI
import AVFoundation

struct AlbumsView: View {
    @State var loadUrl: String
    @State private var albums: [Album] = []
    @State private var scrollOffset: CGFloat = 0
    @State private var activeIndex: Int = 0
    let fileManager = FileManager.default
    var excludeFolder = ["Music", "PioneerDJ"]
    
    var body: some View {
        VStack {
            Spacer();
    
            GeometryReader { outerGeometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(albums.indices, id: \.self) { index in
                            GeometryReader { innerGeometry in
                                VStack {
                                    if let coverImage = albums[index].coverImage {
                                        coverImage
                                            .resizable()
                                            .frame(width: 150, height: 150)
                                            .cornerRadius(10)
                                            .shadow(radius: 5)
                                    } else {
                                        Rectangle()
                                            .fill(Color.gray)
                                            .frame(width: 150, height: 150)
                                            .cornerRadius(10)
                                            .shadow(radius: 5)
                                    }
                                    Text(albums[index].name)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                .scaleEffect(scale(for: innerGeometry.frame(in: .global), in: outerGeometry.frame(in: .global)))
                                .onTapGesture {
                                    scrollOffset = CGFloat(index) * 170 - (outerGeometry.size.width / 2 - 75)
                                    withAnimation {
                                        activeIndex = index
                                    }
                                }
                            }
                            .frame(width: 150, height: 200)
                        }
                    }
                    .padding(.horizontal, (outerGeometry.size.width - 150) / 2)
                    .offset(x: -scrollOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                scrollOffset = value.translation.width - CGFloat(activeIndex) * 170
                            }
                            .onEnded { value in
                                let offset = value.predictedEndTranslation.width + scrollOffset
                                let newIndex = Int(round(-offset / 170))
                                activeIndex = min(max(newIndex, 0), albums.count - 1)
                                withAnimation {
                                    scrollOffset = CGFloat(activeIndex) * 170 - (outerGeometry.size.width / 2 - 75)
                                }
                            }
                    )
                }
            }
        }
        .onAppear(perform: loadDirectories)
    }
    
    private func scale(for innerFrame: CGRect, in outerFrame: CGRect) -> CGFloat {
        let scale = max(0.8, min(1, 1 - abs(innerFrame.midX - outerFrame.midX) / outerFrame.width))
        return scale
    }
    
    private func loadDirectories() {
        let url = URL(fileURLWithPath: loadUrl)
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            let directories = contents.filter { $0.hasDirectoryPath }
            
            albums = directories.compactMap { directoryURL in
                let albumName = directoryURL.lastPathComponent
                let coverImage = getAlbumCover(from: directoryURL)
                    
                if (excludeFolder.contains(albumName))
                {
                    return nil;
                }
                
                return Album(name: albumName, coverImage: coverImage)
            }
        } catch {
            print("Error loading directories: \(error.localizedDescription)")
        }
    }
    
    private func getAlbumCover(from directoryURL: URL) -> Image? {
        do {
            let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            for fileURL in contents where fileURL.pathExtension == "mp3" {
                let asset = AVAsset(url: fileURL)
                for metadataItem in asset.commonMetadata {
                    if metadataItem.commonKey?.rawValue == "artwork", let data = metadataItem.value as? Data, let nsImage = NSImage(data: data) {
                        return Image(nsImage: nsImage)
                    }
                }
            }
        } catch {
            print("Error loading album cover: \(error.localizedDescription)")
        }
        return nil
    }
}
