//! BalanceBar as a native macOS menu-bar (tray) app.
//!
//! Two jobs:
//!   1. Live in the tray. Left-click toggles a small, borderless, always-on-top
//!      popover positioned under the tray icon, and the popover hides when it
//!      loses focus, exactly like a real menu-bar utility.
//!   2. Hold the Investec credentials. The webview never sees the secret: it
//!      calls the `investec_read` command, and this Rust side does the OAuth2
//!      client-credentials exchange and forwards the read-only account calls.
//!      This mirrors the Vite dev-server proxy used by the web prototype, so
//!      the same frontend adapter works in both.

use std::sync::Mutex;
use std::time::{SystemTime, UNIX_EPOCH};

use base64::{engine::general_purpose, Engine as _};
use serde_json::Value;
use tauri::{
    menu::{Menu, MenuItem},
    tray::{TrayIconBuilder, TrayIconEvent},
    Manager, State,
};

/// Sandbox by default. Override with INVESTEC_TOKEN_URL / INVESTEC_API_BASE for
/// production (which uses different hosts).
const DEFAULT_TOKEN_URL: &str = "https://openapisandbox.investec.com/identity/v2/oauth2/token";
const DEFAULT_API_BASE: &str = "https://openapisandbox.investec.com/za/pb/v1";

#[derive(Default)]
struct TokenCache {
    value: Option<String>,
    expires_at: u64,
}

struct Investec {
    client: reqwest::Client,
    cache: Mutex<TokenCache>,
}

impl Investec {
    fn new() -> Self {
        Self {
            client: reqwest::Client::new(),
            cache: Mutex::new(TokenCache::default()),
        }
    }

    fn env(key: &str, default: &str) -> String {
        std::env::var(key).unwrap_or_else(|_| default.to_string())
    }

    async fn token(&self) -> Result<String, String> {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0);
        if let Ok(cache) = self.cache.lock() {
            if let Some(t) = &cache.value {
                if now < cache.expires_at {
                    return Ok(t.clone());
                }
            }
        }

        let client_id = std::env::var("INVESTEC_CLIENT_ID").map_err(|_| "missing INVESTEC_CLIENT_ID")?;
        let secret = std::env::var("INVESTEC_SECRET").map_err(|_| "missing INVESTEC_SECRET")?;
        let api_key = std::env::var("INVESTEC_API_KEY").map_err(|_| "missing INVESTEC_API_KEY")?;
        let basic = general_purpose::STANDARD.encode(format!("{client_id}:{secret}"));

        let res = self
            .client
            .post(Self::env("INVESTEC_TOKEN_URL", DEFAULT_TOKEN_URL))
            .header("Authorization", format!("Basic {basic}"))
            .header("x-api-key", &api_key)
            .header("Content-Type", "application/x-www-form-urlencoded")
            .body("grant_type=client_credentials&scope=accounts")
            .send()
            .await
            .map_err(|e| e.to_string())?;

        let json: Value = res.json().await.map_err(|e| e.to_string())?;
        let token = json["access_token"]
            .as_str()
            .ok_or("no access_token in response")?
            .to_string();
        let ttl = json["expires_in"].as_u64().unwrap_or(1800);

        if let Ok(mut cache) = self.cache.lock() {
            cache.value = Some(token.clone());
            cache.expires_at = now + ttl.saturating_sub(60);
        }
        Ok(token)
    }
}

/// Read-only passthrough to an Investec account path such as "/accounts" or
/// "/accounts/{id}/transactions". Only these read paths are allowed.
#[tauri::command]
async fn investec_read(path: String, state: State<'_, Investec>) -> Result<Value, String> {
    let ok = path == "/accounts"
        || (path.starts_with("/accounts/")
            && (path.ends_with("/balance") || path.ends_with("/transactions")));
    if !ok {
        return Err(format!("path not allowed: {path}"));
    }

    let token = state.token().await?;
    let api_key = std::env::var("INVESTEC_API_KEY").map_err(|_| "missing INVESTEC_API_KEY")?;
    let base = Investec::env("INVESTEC_API_BASE", DEFAULT_API_BASE);

    let res = state
        .client
        .get(format!("{base}{path}"))
        .header("Authorization", format!("Bearer {token}"))
        .header("x-api-key", api_key)
        .send()
        .await
        .map_err(|e| e.to_string())?;

    res.json::<Value>().await.map_err(|e| e.to_string())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_positioner::init())
        .manage(Investec::new())
        .invoke_handler(tauri::generate_handler![investec_read])
        .setup(|app| {
            let show = MenuItem::with_id(app, "show", "Show BalanceBar", true, None::<&str>)?;
            let quit = MenuItem::with_id(app, "quit", "Quit", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&show, &quit])?;

            let _tray = TrayIconBuilder::with_id("balancebar")
                .tooltip("BalanceBar")
                .menu(&menu)
                .show_menu_on_left_click(false)
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "quit" => app.exit(0),
                    "show" => toggle_popover(app),
                    _ => {}
                })
                .on_tray_icon_event(|tray, event| {
                    tauri_plugin_positioner::on_tray_event(tray.app_handle(), &event);
                    if let TrayIconEvent::Click { .. } = event {
                        toggle_popover(tray.app_handle());
                    }
                })
                .build(app)?;

            // Hide the popover when it loses focus, like a real menu-bar app.
            if let Some(win) = app.get_webview_window("popover") {
                let w = win.clone();
                win.on_window_event(move |event| {
                    if let tauri::WindowEvent::Focused(false) = event {
                        let _ = w.hide();
                    }
                });
            }
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running BalanceBar");
}

fn toggle_popover<R: tauri::Runtime>(app: &tauri::AppHandle<R>) {
    if let Some(win) = app.get_webview_window("popover") {
        if win.is_visible().unwrap_or(false) {
            let _ = win.hide();
        } else {
            use tauri_plugin_positioner::{Position, WindowExt};
            let _ = win.move_window(Position::TrayCenter);
            let _ = win.show();
            let _ = win.set_focus();
        }
    }
}
