//
//  LoadAudioFiles.swift
//  Pod
//
//  Created by Iskren Alexandrov on 23.06.24.
//

import AVFoundation

func loadAudioFiles(from directory: String) -> [Song] {
    var songs = [Song]()
    let fileManager = FileManager.default
    let url = URL(fileURLWithPath: directory)
    
    do {
        let fileURLs = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        for fileURL in fileURLs {
            if fileURL.pathExtension == "mp3" {
                let asset = AVAsset(url: fileURL)
                var title = fileURL.deletingPathExtension().lastPathComponent
                var artist: String? = nil
                var album: String? = nil
                
                for metadataItem in asset.metadata {
                    if let key = metadataItem.commonKey?.rawValue {
                        switch key {
                        case "title":
                            title = metadataItem.stringValue ?? title
                        case "artist":
                            artist = metadataItem.stringValue
                        case "albumName":
                            album = metadataItem.stringValue
                        default:
                            break
                        }
                    }
                }
                
                let song = Song(title: title, artist: artist, album: album, pathToAudioFile: fileURL.path)
                songs.append(song)
            }
        }
    } catch {
        print("Error while enumerating files \(directory): \(error.localizedDescription)")
    }
    
    return songs
}

