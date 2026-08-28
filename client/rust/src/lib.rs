// SPDX-License-Identifier: MPL-2.0

//! Embeddable Rust access to Burble's non-voice game-session lane.
//!
//! [`GameClient::join`] is the high-level entry point. It connects to a
//! Burble Phoenix socket, authenticates, and joins one `game:<session_id>`
//! topic. The lower-level [`PhoenixClient`] and [`TextTransport`] types are
//! public so applications can supply a different WebSocket implementation.

mod error;
mod game;
mod phoenix;
mod transport;

pub use error::Error;
pub use game::{Auth, GameBroadcast, GameClient, JoinConfig, RelayOutcome};
pub use phoenix::{Broadcast, PhoenixClient};
pub use transport::{TextTransport, WebSocketTransport};
