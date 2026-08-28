// SPDX-License-Identifier: MPL-2.0

use burble_client::{Auth, GameBroadcast, GameClient, JoinConfig, RelayOutcome};
use serde_json::json;
use std::{env, time::Duration};

fn config(endpoint: &str, session: &str, role: &str) -> JoinConfig {
    JoinConfig {
        endpoint: endpoint.to_owned(),
        session_id: session.to_owned(),
        game_id: "idaptik".into(),
        role: role.into(),
        auth: Auth::Guest {
            display_name: format!("rust-{role}"),
        },
    }
}

async fn next_command(
    client: &mut GameClient,
) -> Result<Option<GameBroadcast>, Box<dyn std::error::Error>> {
    loop {
        match client.next_event(Duration::from_secs(2)).await? {
            command @ Some(GameBroadcast::Command(_)) => return Ok(command),
            Some(_) => continue,
            None => return Err("timed out waiting for relayed command".into()),
        }
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let endpoint = env::var("BURBLE_TEST_URL")
        .unwrap_or_else(|_| "ws://127.0.0.1:6473/voice/websocket".into());
    let session = format!("rust-client-{}", std::process::id());
    let mut infiltrator = GameClient::join(config(&endpoint, &session, "infiltrator")).await?;
    let mut hacker = GameClient::join(config(&endpoint, &session, "hacker")).await?;
    hacker.ping().await?;

    assert_eq!(
        infiltrator
            .send_command(json!({"cmd": "SetButton", "button": "Right", "down": true, "seq": 1}))
            .await?,
        RelayOutcome::Relayed
    );
    let received = hacker.next_event(Duration::from_secs(2)).await?;
    assert_eq!(
        received,
        Some(GameBroadcast::Command(
            json!({"cmd": "SetButton", "button": "Right", "down": true})
        ))
    );

    assert_eq!(
        hacker
            .send_command(json!({"cmd": "Pivot", "target": "IspOps", "seq": 1}))
            .await?,
        RelayOutcome::Relayed
    );
    // The first seat also has peer_joined queued; preserve it and keep reading.
    let received = next_command(&mut infiltrator).await?;
    assert_eq!(
        received,
        Some(GameBroadcast::Command(
            json!({"cmd": "Pivot", "target": "IspOps"})
        ))
    );

    assert!(matches!(
        hacker
            .send_command(json!({"cmd": "Pivot", "target": "IspOps", "seq": 1}))
            .await?,
        RelayOutcome::Dropped { .. }
    ));
    infiltrator.leave().await;
    hacker.leave().await;
    println!("Burble Rust client live round-trip passed at {endpoint}");
    Ok(())
}
