<!-- SPDX-License-Identifier: MPL-2.0 -->

# burble-client

Embeddable Rust client for Burble's non-voice `game:<session_id>` channel.
It speaks the Phoenix V2 JSON protocol used by Burble 1.x and exposes the
game lane without requiring Phoenix or JavaScript in the consuming program.

```rust,no_run
use burble_client::{Auth, GameClient, JoinConfig};

# async fn connect() -> Result<(), burble_client::Error> {
let client = GameClient::join(JoinConfig {
    endpoint: "ws://127.0.0.1:6473/voice/websocket".into(),
    session_id: "shared-session-code".into(),
    game_id: "idaptik".into(),
    role: "hacker".into(),
    auth: Auth::Guest { display_name: "Ada".into() },
}).await?;
# drop(client); Ok(()) }
```

The endpoint may be `ws://` or `wss://`. Existing query parameters are
preserved; authentication and `vsn=2.0.0` are appended safely. Use
`Auth::Token` where the Burble deployment requires authenticated accounts.

Run unit tests with `cargo test --manifest-path client/rust/Cargo.toml`. For a
live two-seat proof, start Burble and run:

```console
BURBLE_TEST_URL=ws://127.0.0.1:6473/voice/websocket \
  cargo run --manifest-path client/rust/Cargo.toml --example idaptik_roundtrip
```
