use crate::protocol::{Event, Response};
use crate::{send_event, send_response, BridgeState};
use librespot_core::authentication::Credentials;
use librespot_core::{Session, SessionConfig};
use serde_json::Value;
use std::sync::Arc;
use tokio::sync::Mutex;

// Spotify's official desktop client ID (used by librespot)
const SPOTIFY_CLIENT_ID: &str = "65b708073fc0480ea92a077233ca87bd";
const REDIRECT_URI: &str = "http://127.0.0.1:5588/login";

const AUTH_SUCCESS_HTML: &str = r##"
<div style="display:flex;justify-content:center;align-items:center;min-height:100vh;background:#000;margin:0;font-family:'Circular',Helvetica,Arial,sans-serif">
  <div style="text-align:center">
    <svg width="48" height="48" viewBox="0 0 24 24" fill="none" style="margin-bottom:24px"><circle cx="12" cy="12" r="12" fill="#1DB954"/><path d="M9 16.2L4.8 12l-1.4 1.4L9 19 21 7l-1.4-1.4L9 16.2z" fill="#000"/></svg>
    <h1 style="color:#fff;font-size:32px;font-weight:700;margin:0 0 8px">Successfully connected to Pod</h1>
    <p style="color:#a7a7a7;font-size:16px;margin:0 0 32px">You can close this tab.</p>
    <button onclick="window.close()" style="background:#1DB954;color:#000;border:none;border-radius:500px;padding:14px 48px;font-size:16px;font-weight:700;cursor:pointer;font-family:inherit;transition:transform .1s,background .1s" onmouseover="this.style.transform='scale(1.04)';this.style.background='#1ed760'" onmouseout="this.style.transform='scale(1)';this.style.background='#1DB954'">Close</button>
  </div>
</div>
<style>body{margin:0;background:#000}</style>
"##;

pub async fn handle_auth_start(state: Arc<Mutex<BridgeState>>, id: u64) {
    let scopes = vec![
        "streaming",
        "user-read-email",
        "user-read-private",
        "playlist-read-private",
        "playlist-read-collaborative",
        "user-library-read",
    ];

    // OAuth flow: opens browser, starts local HTTP server for callback
    let token_result = tokio::task::spawn_blocking(move || {
        let client = librespot_oauth::OAuthClientBuilder::new(SPOTIFY_CLIENT_ID, REDIRECT_URI, scopes)
            .open_in_browser()
            .with_custom_message(AUTH_SUCCESS_HTML)
            .build()?;
        client.get_access_token()
    })
    .await;

    let token = match token_result {
        Ok(Ok(t)) => t,
        Ok(Err(e)) => {
            send_response(&Response::error(id, &format!("OAuth failed: {}", e)));
            return;
        }
        Err(e) => {
            send_response(&Response::error(id, &format!("Task join error: {}", e)));
            return;
        }
    };

    let credentials = Credentials::with_access_token(&token.access_token);
    let session_config = SessionConfig::default();
    let session = Session::new(session_config, None);

    if let Err(e) = session.connect(credentials.clone(), true).await {
        send_response(&Response::error(id, &format!("Session connect failed: {}", e)));
        return;
    }

    let creds_json = serde_json::json!({
        "access_token": token.access_token,
        "refresh_token": token.refresh_token,
        "token_type": token.token_type,
        "scopes": token.scopes,
    });

    let mut s = state.lock().await;
    s.session = Some(session);
    s.access_token = Some(token.access_token.clone());

    send_response(&Response::ok(
        id,
        serde_json::json!({
            "authenticated": true,
            "credentials": creds_json,
        }),
    ));
    send_event(&Event::new(
        "auth_complete",
        serde_json::json!({"authenticated": true}),
    ));
}

pub async fn handle_auth_stored(
    state: Arc<Mutex<BridgeState>>,
    id: u64,
    creds_json: Option<Value>,
) {
    let access_token = creds_json
        .as_ref()
        .and_then(|v| v.get("access_token"))
        .and_then(|v| v.as_str());

    let access_token = match access_token {
        Some(t) => t.to_string(),
        None => {
            send_response(&Response::error(id, "Missing access_token in credentials"));
            return;
        }
    };

    let credentials = Credentials::with_access_token(&access_token);
    let session_config = SessionConfig::default();
    let session = Session::new(session_config, None);

    if let Err(e) = session.connect(credentials, true).await {
        send_response(&Response::error(id, &format!("Session connect failed: {}", e)));
        return;
    }

    let mut s = state.lock().await;
    s.session = Some(session);
    s.access_token = Some(access_token);

    send_response(&Response::ok(id, serde_json::json!({"authenticated": true})));
    send_event(&Event::new(
        "auth_complete",
        serde_json::json!({"authenticated": true}),
    ));
}
