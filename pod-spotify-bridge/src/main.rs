mod auth;
mod metadata;
mod playback;
mod protocol;

use protocol::{Request, Response, Event};
use std::io::{self, BufRead, Write};
use std::sync::Arc;
use tokio::sync::Mutex;

struct BridgeState {
    session: Option<librespot_core::Session>,
    player: Option<playback::PlayerHandle>,
    credentials_cache_path: Option<String>,
    access_token: Option<String>,
}

impl BridgeState {
    fn new() -> Self {
        Self {
            session: None,
            player: None,
            credentials_cache_path: None,
            access_token: None,
        }
    }
}

fn send_response(resp: &Response) {
    let json = serde_json::to_string(resp).unwrap();
    let stdout = io::stdout();
    let mut handle = stdout.lock();
    let _ = writeln!(handle, "{}", json);
    let _ = handle.flush();
}

fn send_event(event: &Event) {
    let json = serde_json::to_string(event).unwrap();
    let stdout = io::stdout();
    let mut handle = stdout.lock();
    let _ = writeln!(handle, "{}", json);
    let _ = handle.flush();
}

#[tokio::main]
async fn main() {
    env_logger::init();

    let state = Arc::new(Mutex::new(BridgeState::new()));

    // Read JSON lines from stdin
    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        let line = match line {
            Ok(l) => l,
            Err(_) => break,
        };

        if line.trim().is_empty() {
            continue;
        }

        let req: Request = match serde_json::from_str(&line) {
            Ok(r) => r,
            Err(e) => {
                send_response(&Response::error(0, &format!("Invalid JSON: {}", e)));
                continue;
            }
        };

        let state = state.clone();
        // Process each request (could spawn tasks for long-running ones)
        tokio::spawn(async move {
            dispatch(state, req).await;
        });
    }
}

async fn dispatch(state: Arc<Mutex<BridgeState>>, req: Request) {
    let id = req.id;
    match req.method.as_str() {
        "auth_start" => {
            auth::handle_auth_start(state, id).await;
        }
        "auth_stored" => {
            let creds_json = req.params.and_then(|p| p.get("credentials").cloned());
            auth::handle_auth_stored(state, id, creds_json).await;
        }
        "disconnect" => {
            let mut s = state.lock().await;
            if let Some(player) = s.player.take() {
                player.stop();
            }
            s.session = None;
            send_response(&Response::ok(id, serde_json::json!({"disconnected": true})));
        }

        // Playback
        "play" => {
            let uri = req.params.as_ref().and_then(|p| p.get("uri")).and_then(|v| v.as_str());
            if let Some(uri) = uri {
                playback::handle_play(state, id, uri).await;
            } else {
                send_response(&Response::error(id, "Missing 'uri' param"));
            }
        }
        "play_context" => {
            let context_uri = req.params.as_ref().and_then(|p| p.get("context_uri")).and_then(|v| v.as_str());
            let offset = req.params.as_ref().and_then(|p| p.get("offset")).and_then(|v| v.as_u64()).unwrap_or(0) as usize;
            if let Some(context_uri) = context_uri {
                playback::handle_play_context(state, id, context_uri, offset).await;
            } else {
                send_response(&Response::error(id, "Missing 'context_uri' param"));
            }
        }
        "pause" => playback::handle_pause(state, id).await,
        "resume" => playback::handle_resume(state, id).await,
        "seek" => {
            let pos = req.params.as_ref().and_then(|p| p.get("position_ms")).and_then(|v| v.as_u64()).unwrap_or(0) as u32;
            playback::handle_seek(state, id, pos).await;
        }
        "set_volume" => {
            let vol = req.params.as_ref().and_then(|p| p.get("volume")).and_then(|v| v.as_f64()).unwrap_or(0.6) as f32;
            playback::handle_set_volume(state, id, vol).await;
        }

        // Metadata
        "get_playlists" => metadata::handle_get_playlists(state, id).await,
        "get_saved_albums" => metadata::handle_get_saved_albums(state, id).await,
        "get_playlist_tracks" => {
            let playlist_id = req.params.as_ref().and_then(|p| p.get("playlist_id")).and_then(|v| v.as_str());
            if let Some(pid) = playlist_id {
                metadata::handle_get_playlist_tracks(state, id, pid).await;
            } else {
                send_response(&Response::error(id, "Missing 'playlist_id' param"));
            }
        }
        "get_album_tracks" => {
            let album_id = req.params.as_ref().and_then(|p| p.get("album_id")).and_then(|v| v.as_str());
            if let Some(aid) = album_id {
                metadata::handle_get_album_tracks(state, id, aid).await;
            } else {
                send_response(&Response::error(id, "Missing 'album_id' param"));
            }
        }

        _ => {
            send_response(&Response::error(id, &format!("Unknown method: {}", req.method)));
        }
    }
}
