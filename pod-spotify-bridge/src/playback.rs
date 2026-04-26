use crate::protocol::{Event, Response};
use crate::{send_event, send_response, BridgeState};
use librespot_core::SpotifyUri;
use librespot_playback::audio_backend;
use librespot_playback::config::{AudioFormat, Bitrate, PlayerConfig};
use librespot_playback::mixer::NoOpVolume;
use librespot_playback::player::Player;
use std::sync::Arc;
use tokio::sync::Mutex;

pub struct PlayerHandle {
    pub player: Arc<Player>,
}

impl PlayerHandle {
    pub fn stop(&self) {
        self.player.stop();
    }
}

fn ensure_player(state: &mut BridgeState) -> Result<(), String> {
    if state.player.is_some() {
        return Ok(());
    }

    let session = state.session.as_ref().ok_or("Not authenticated")?;

    let player_config = PlayerConfig {
        bitrate: Bitrate::Bitrate320,
        position_update_interval: Some(std::time::Duration::from_secs(1)),
        ..Default::default()
    };

    let backend = audio_backend::find(None).ok_or("No audio backend found")?;

    let player = Player::new(
        player_config,
        session.clone(),
        Box::new(NoOpVolume),
        move || backend(None, AudioFormat::S16),
    );

    // Spawn event listener
    let player_clone = player.clone();
    tokio::spawn(async move {
        let mut channel = player_clone.get_player_event_channel();
        while let Some(event) = channel.recv().await {
            handle_player_event(event);
        }
    });

    state.player = Some(PlayerHandle { player });
    Ok(())
}

fn handle_player_event(event: librespot_playback::player::PlayerEvent) {
    use librespot_playback::player::PlayerEvent;
    match event {
        PlayerEvent::Playing {
            track_id,
            position_ms,
            ..
        } => {
            send_event(&Event::new(
                "player_state",
                serde_json::json!({
                    "is_playing": true,
                    "position_ms": position_ms,
                    "track_uri": track_id.to_string(),
                }),
            ));
        }
        PlayerEvent::Paused {
            track_id,
            position_ms,
            ..
        } => {
            send_event(&Event::new(
                "player_state",
                serde_json::json!({
                    "is_playing": false,
                    "position_ms": position_ms,
                    "track_uri": track_id.to_string(),
                }),
            ));
        }
        PlayerEvent::Stopped { .. } => {
            send_event(&Event::new(
                "player_state",
                serde_json::json!({
                    "is_playing": false,
                    "position_ms": 0,
                }),
            ));
        }
        PlayerEvent::EndOfTrack { .. } => {
            send_event(&Event::new("track_end", serde_json::json!({})));
        }
        PlayerEvent::Loading { track_id, .. } => {
            send_event(&Event::new(
                "loading",
                serde_json::json!({
                    "track_uri": track_id.to_string(),
                }),
            ));
        }
        PlayerEvent::PositionChanged {
            track_id,
            position_ms,
            ..
        } => {
            send_event(&Event::new(
                "player_state",
                serde_json::json!({
                    "is_playing": true,
                    "position_ms": position_ms,
                    "track_uri": track_id.to_string(),
                }),
            ));
        }
        _ => {}
    }
}

pub async fn handle_play(state: Arc<Mutex<BridgeState>>, id: u64, uri: &str) {
    let mut s = state.lock().await;

    if let Err(e) = ensure_player(&mut s) {
        send_response(&Response::error(id, &e));
        return;
    }

    let track_uri = match SpotifyUri::from_uri(uri) {
        Ok(u) => u,
        Err(e) => {
            send_response(&Response::error(id, &format!("Invalid URI '{}': {}", uri, e)));
            return;
        }
    };

    if let Some(ref handle) = s.player {
        handle.player.load(track_uri, true, 0);
        send_response(&Response::ok(id, serde_json::json!({"playing": true})));
    }
}

pub async fn handle_play_context(
    state: Arc<Mutex<BridgeState>>,
    id: u64,
    _context_uri: &str,
    _offset: usize,
) {
    // Swift side will fetch tracks via metadata and play individually
    let _ = state;
    send_response(&Response::error(
        id,
        "play_context not implemented - use play with individual track URIs",
    ));
}

pub async fn handle_pause(state: Arc<Mutex<BridgeState>>, id: u64) {
    let s = state.lock().await;
    if let Some(ref handle) = s.player {
        handle.player.pause();
        send_response(&Response::ok(id, serde_json::json!({"paused": true})));
    } else {
        send_response(&Response::error(id, "No player"));
    }
}

pub async fn handle_resume(state: Arc<Mutex<BridgeState>>, id: u64) {
    let s = state.lock().await;
    if let Some(ref handle) = s.player {
        handle.player.play();
        send_response(&Response::ok(id, serde_json::json!({"playing": true})));
    } else {
        send_response(&Response::error(id, "No player"));
    }
}

pub async fn handle_seek(state: Arc<Mutex<BridgeState>>, id: u64, position_ms: u32) {
    let s = state.lock().await;
    if let Some(ref handle) = s.player {
        handle.player.seek(position_ms);
        send_response(&Response::ok(
            id,
            serde_json::json!({"seeked": position_ms}),
        ));
    } else {
        send_response(&Response::error(id, "No player"));
    }
}

pub async fn handle_set_volume(state: Arc<Mutex<BridgeState>>, id: u64, _volume: f32) {
    let _ = state;
    send_response(&Response::ok(
        id,
        serde_json::json!({"volume_note": "OS-level volume"}),
    ));
}
