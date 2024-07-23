//
//  ItunesView.swift
//  Pod
//
//  Created by Iskren Alexandrov on 23.07.24.
//

import SwiftUI
import iTunesLibrary
import AVFoundation

struct ItunesView: View {
    @State private var mediaItems: [ITLibMediaItem] = []
    @State private var audioPlayer: AVAudioPlayer?
    
    var body: some View {
        VStack {
            List(mediaItems, id: \.persistentID) { item in
                Button(action: {
                    self.play(item: item)
                }) {
                    Text(item.title)
                }
            }
        }
        .onAppear(perform: loadMediaLibrary)
    }
    
    private func loadMediaLibrary() {
        do {
            let library = try ITLibrary(apiVersion: "1.0")
            let items = library.allMediaItems.filter {
                            $0.mediaKind == .kindSong && $0.location != nil
                        }            
            DispatchQueue.main.async {
                self.mediaItems = items
            }
        } catch {
            print("Failed to load media library: \(error.localizedDescription)")
        }
    }
    
    private func play(item: ITLibMediaItem) {
        guard let location = item.location else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: location)
            audioPlayer?.play()
        } catch {
            print("Failed to play audio: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ItunesView()
}
