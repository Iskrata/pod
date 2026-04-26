use crate::protocol::Response;
use crate::{send_response, BridgeState};
use http::Method;
use librespot_core::{SpotifyId, SpotifyUri};
use librespot_metadata::{Album, Artist, Metadata, Playlist, Track};
use std::sync::Arc;
use tokio::sync::Mutex;

fn image_url_from_file_id(file_id: &librespot_core::FileId) -> String {
    format!("https://i.scdn.co/image/{}", hex::encode(file_id.0))
}

pub async fn handle_get_playlists(state: Arc<Mutex<BridgeState>>, id: u64) {
    let s = state.lock().await;
    let session = match &s.session {
        Some(s) => s.clone(),
        None => {
            send_response(&Response::error(id, "Not authenticated"));
            return;
        }
    };
    drop(s);

    match session.spclient().get_rootlist(0, None).await {
        Ok(bytes) => match parse_rootlist_playlists(&session, &bytes).await {
            Ok(playlists) => {
                send_response(&Response::ok(
                    id,
                    serde_json::json!({"playlists": playlists}),
                ));
            }
            Err(e) => {
                send_response(&Response::error(
                    id,
                    &format!("Failed to parse playlists: {}", e),
                ));
            }
        },
        Err(e) => {
            send_response(&Response::error(
                id,
                &format!("Failed to fetch rootlist: {}", e),
            ));
        }
    }
}

async fn parse_rootlist_playlists(
    session: &librespot_core::Session,
    data: &[u8],
) -> Result<Vec<serde_json::Value>, String> {
    use librespot_protocol::playlist4_external::SelectedListContent;
    use protobuf::Message;

    let rootlist = SelectedListContent::parse_from_bytes(data)
        .map_err(|e| format!("Protobuf parse error: {}", e))?;

    let mut playlists = Vec::new();

    if let Some(contents) = rootlist.contents.as_ref() {
        for item in &contents.items {
            let uri_str = item.uri.as_deref().unwrap_or("");
            if !uri_str.starts_with("spotify:playlist:") {
                continue;
            }

            if let Ok(uri) = SpotifyUri::from_uri(uri_str) {
                if let SpotifyUri::Playlist { id: playlist_sid, .. } = &uri {
                    match Playlist::get(session, &uri).await {
                        Ok(playlist) => {
                            let name = playlist.attributes.name.clone();
                            let track_count = playlist.length as usize;

                            let image_url: Option<String> = if !playlist.attributes.picture.is_empty() {
                                Some(format!("https://mosaic.scdn.co/300/{}", hex::encode(&playlist.attributes.picture)))
                            } else {
                                None
                            };

                            playlists.push(serde_json::json!({
                                "id": playlist_sid.to_base62().unwrap_or_default(),
                                "name": name,
                                "imageUrl": image_url,
                                "trackCount": track_count,
                            }));
                        }
                        Err(e) => {
                            log::warn!("Failed to fetch playlist {}: {}", uri_str, e);
                        }
                    }
                }
            }
        }
    }

    Ok(playlists)
}

pub async fn handle_get_saved_albums(state: Arc<Mutex<BridgeState>>, id: u64) {
    let s = state.lock().await;
    let session = match &s.session {
        Some(s) => s.clone(),
        None => {
            send_response(&Response::error(id, "Not authenticated"));
            return;
        }
    };
    drop(s);

    // Extract unique albums from: liked songs + all playlists
    // All via spclient/librespot internal protocol — no Web API rate limits
    let mut seen_album_ids = std::collections::HashSet::new();
    let mut albums = Vec::new();

    // 1. Get albums from liked songs (user collection context)
    let username = session.username();
    let collection_uri = format!("spotify:user:{}:collection", username);
    eprintln!("[bridge] fetching liked songs from {}", collection_uri);

    if let Ok(context) = session.spclient().get_context(&collection_uri).await {
        for page in &context.pages {
            for track in &page.tracks {
                if let Some(uri) = track.uri.as_ref() {
                    if let Ok(track_uri) = SpotifyUri::from_uri(uri) {
                        if let Ok(track_meta) = Track::get(&session, &track_uri).await {
                            let album_uri_str = track_meta.album.id.to_uri().unwrap_or_default();
                            let album_id = album_uri_str.split(':').last().unwrap_or("").to_string();
                            if !album_id.is_empty() && seen_album_ids.insert(album_id.clone()) {
                                let artist_name = track_meta.album.artists.0.first()
                                    .map(|a| a.name.clone())
                                    .unwrap_or_else(|| "Unknown Artist".to_string());
                                let image_url = track_meta.album.covers.0.first()
                                    .map(|img| image_url_from_file_id(&img.id));
                                let track_count: usize = track_meta.album.discs.0.iter()
                                    .map(|d| d.tracks.0.len()).sum();

                                albums.push(serde_json::json!({
                                    "id": album_id,
                                    "name": track_meta.album.name,
                                    "artist": artist_name,
                                    "imageUrl": image_url,
                                    "trackCount": track_count,
                                    "uri": album_uri_str,
                                }));
                            }
                        }
                    }
                }
            }
        }
    }

    eprintln!("[bridge] found {} unique albums from liked songs", albums.len());

    // 2. Get albums from all playlists
    if let Ok(rootlist_bytes) = session.spclient().get_rootlist(0, None).await {
        if let Ok(playlist_uris) = extract_playlist_uris(&rootlist_bytes) {
            eprintln!("[bridge] scanning {} playlists for albums", playlist_uris.len());
            for playlist_uri_str in &playlist_uris {
                if let Ok(uri) = SpotifyUri::from_uri(playlist_uri_str) {
                    if let Ok(playlist) = Playlist::get(&session, &uri).await {
                        // Sample first 50 tracks per playlist to keep it fast
                        let track_uris: Vec<SpotifyUri> = playlist.contents.items.iter()
                            .take(50)
                            .map(|item| item.id.clone())
                            .collect();

                        for track_uri in &track_uris {
                            if !track_uri.is_playable() { continue; }
                            if let Ok(track_meta) = Track::get(&session, track_uri).await {
                                let album_uri_str = track_meta.album.id.to_uri().unwrap_or_default();
                                let album_id = album_uri_str.split(':').last().unwrap_or("").to_string();
                                if !album_id.is_empty() && seen_album_ids.insert(album_id.clone()) {
                                    let artist_name = track_meta.album.artists.0.first()
                                        .map(|a| a.name.clone())
                                        .unwrap_or_else(|| "Unknown Artist".to_string());
                                    let image_url = track_meta.album.covers.0.first()
                                        .map(|img| image_url_from_file_id(&img.id));
                                    let track_count: usize = track_meta.album.discs.0.iter()
                                        .map(|d| d.tracks.0.len()).sum();

                                    albums.push(serde_json::json!({
                                        "id": album_id,
                                        "name": track_meta.album.name,
                                        "artist": artist_name,
                                        "imageUrl": image_url,
                                        "trackCount": track_count,
                                        "uri": album_uri_str,
                                    }));
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    eprintln!("[bridge] total unique albums: {}", albums.len());
    send_response(&Response::ok(id, serde_json::json!({"albums": albums})));
}

fn extract_playlist_uris(data: &[u8]) -> Result<Vec<String>, String> {
    use librespot_protocol::playlist4_external::SelectedListContent;
    use protobuf::Message;

    let rootlist = SelectedListContent::parse_from_bytes(data)
        .map_err(|e| format!("Protobuf parse error: {}", e))?;

    let mut uris = Vec::new();
    if let Some(contents) = rootlist.contents.as_ref() {
        for item in &contents.items {
            if let Some(uri) = item.uri.as_deref() {
                if uri.starts_with("spotify:playlist:") {
                    uris.push(uri.to_string());
                }
            }
        }
    }
    Ok(uris)
}

async fn fetch_albums_web_api(state: Arc<Mutex<BridgeState>>, id: u64) {
    let s = state.lock().await;
    let access_token = match &s.access_token {
        Some(t) => t.clone(),
        None => {
            send_response(&Response::error(id, "No access token for Web API fallback"));
            return;
        }
    };
    drop(s);

    let mut all_albums = Vec::new();
    let mut offset = 0u32;
    let limit = 50u32;
    let client = reqwest::Client::new();

    loop {
        let url = format!(
            "https://api.spotify.com/v1/me/albums?limit={}&offset={}",
            limit, offset
        );

        let mut retries = 0u32;
        let json: serde_json::Value = loop {
            let resp = match client
                .get(&url)
                .header("Authorization", format!("Bearer {}", access_token))
                .send()
                .await
            {
                Ok(r) => r,
                Err(e) => {
                    send_response(&Response::error(id, &format!("HTTP error: {}", e)));
                    return;
                }
            };

            if resp.status() == 429 {
                let retry_after = resp
                    .headers()
                    .get("retry-after")
                    .and_then(|v| v.to_str().ok())
                    .and_then(|v| v.parse::<u64>().ok())
                    .unwrap_or(2);
                retries += 1;
                if retries > 3 {
                    send_response(&Response::error(id, "Rate limited"));
                    return;
                }
                tokio::time::sleep(std::time::Duration::from_secs(retry_after.min(10))).await;
                continue;
            }

            match resp.json().await {
                Ok(j) => break j,
                Err(e) => {
                    send_response(&Response::error(id, &format!("JSON error: {}", e)));
                    return;
                }
            }
        };

        if let Some(items) = json["items"].as_array() {
            if items.is_empty() { break; }
            for item in items {
                let album = &item["album"];
                all_albums.push(serde_json::json!({
                    "id": album["id"].as_str().unwrap_or_default(),
                    "name": album["name"].as_str().unwrap_or_default(),
                    "artist": album["artists"].as_array()
                        .and_then(|a| a.first())
                        .and_then(|a| a["name"].as_str())
                        .unwrap_or("Unknown Artist"),
                    "imageUrl": album["images"].as_array()
                        .and_then(|i| i.first())
                        .and_then(|i| i["url"].as_str()),
                    "trackCount": album["total_tracks"].as_u64().unwrap_or(0),
                    "uri": album["uri"].as_str().unwrap_or_default(),
                }));
            }
        } else { break; }

        let total = json["total"].as_u64().unwrap_or(0);
        offset += limit;
        if offset as u64 >= total { break; }
    }

    send_response(&Response::ok(id, serde_json::json!({"albums": all_albums})));
}

pub async fn handle_get_playlist_tracks(
    state: Arc<Mutex<BridgeState>>,
    id: u64,
    playlist_id: &str,
) {
    let s = state.lock().await;
    let session = match &s.session {
        Some(s) => s.clone(),
        None => {
            send_response(&Response::error(id, "Not authenticated"));
            return;
        }
    };
    drop(s);

    let playlist_sid = match SpotifyId::from_base62(playlist_id) {
        Ok(sid) => sid,
        Err(_) => {
            send_response(&Response::error(id, "Invalid playlist ID"));
            return;
        }
    };

    let uri = SpotifyUri::Playlist {
        user: None,
        id: playlist_sid,
    };

    match Playlist::get(&session, &uri).await {
        Ok(playlist) => {
            let track_uris: Vec<SpotifyUri> = playlist
                .contents
                .items
                .iter()
                .map(|item| item.id.clone())
                .collect();

            let tracks = fetch_tracks_metadata(&session, &track_uris).await;
            send_response(&Response::ok(id, serde_json::json!({"tracks": tracks})));
        }
        Err(e) => {
            send_response(&Response::error(
                id,
                &format!("Failed to fetch playlist: {}", e),
            ));
        }
    }
}

pub async fn handle_get_album_tracks(
    state: Arc<Mutex<BridgeState>>,
    id: u64,
    album_id: &str,
) {
    let s = state.lock().await;
    let session = match &s.session {
        Some(s) => s.clone(),
        None => {
            send_response(&Response::error(id, "Not authenticated"));
            return;
        }
    };
    drop(s);

    let album_sid = match SpotifyId::from_base62(album_id) {
        Ok(sid) => sid,
        Err(_) => {
            send_response(&Response::error(id, "Invalid album ID"));
            return;
        }
    };

    let uri = SpotifyUri::Album { id: album_sid };

    match Album::get(&session, &uri).await {
        Ok(album) => {
            let album_image_url = album.covers.first().map(|img| image_url_from_file_id(&img.id));

            let mut tracks = Vec::new();
            for disc in album.discs.iter() {
                for track_uri in disc.tracks.iter() {
                    match Track::get(&session, track_uri).await {
                        Ok(track) => {
                            let artist_name =
                                get_first_artist_name(&track.artists);

                            let track_id = match SpotifyId::try_from(&track.id) {
                                Ok(sid) => sid.to_base62().unwrap_or_default(),
                                Err(_) => String::new(),
                            };

                            tracks.push(serde_json::json!({
                                "id": track_id,
                                "uri": track.id.to_string(),
                                "name": track.name,
                                "artist": artist_name,
                                "album": album.name,
                                "albumImageUrl": album_image_url,
                                "durationMs": track.duration,
                            }));
                        }
                        Err(e) => {
                            log::warn!("Failed to fetch track: {}", e);
                        }
                    }
                }
            }
            send_response(&Response::ok(id, serde_json::json!({"tracks": tracks})));
        }
        Err(e) => {
            send_response(&Response::error(
                id,
                &format!("Failed to fetch album: {}", e),
            ));
        }
    }
}

async fn fetch_tracks_metadata(
    session: &librespot_core::Session,
    track_uris: &[SpotifyUri],
) -> Vec<serde_json::Value> {
    let mut tracks = Vec::new();

    for track_uri in track_uris {
        if !track_uri.is_playable() {
            continue;
        }

        match Track::get(session, track_uri).await {
            Ok(track) => {
                let artist_name = get_first_artist_name(&track.artists);

                let album_name = &track.album.name;
                let album_image = track
                    .album
                    .covers
                    .first()
                    .map(|img| image_url_from_file_id(&img.id));

                let track_id = match SpotifyId::try_from(&track.id) {
                    Ok(sid) => sid.to_base62().unwrap_or_default(),
                    Err(_) => String::new(),
                };

                tracks.push(serde_json::json!({
                    "id": track_id,
                    "uri": track.id.to_string(),
                    "name": track.name,
                    "artist": artist_name,
                    "album": album_name,
                    "albumImageUrl": album_image,
                    "durationMs": track.duration,
                }));
            }
            Err(e) => {
                log::warn!("Failed to fetch track: {}", e);
            }
        }
    }

    tracks
}

fn get_first_artist_name(artists: &librespot_metadata::artist::Artists) -> String {
    artists
        .first()
        .map(|a| a.name.clone())
        .unwrap_or_else(|| "Unknown Artist".to_string())
}
