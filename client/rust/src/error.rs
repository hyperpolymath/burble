// SPDX-License-Identifier: MPL-2.0

use std::fmt;

/// Failure returned by the transport, Phoenix protocol, or Burble channel.
#[derive(Debug)]
pub enum Error {
    Url(url::ParseError),
    WebSocket(tokio_tungstenite::tungstenite::Error),
    Json(serde_json::Error),
    Protocol(String),
    Rejected {
        status: String,
        response: serde_json::Value,
    },
    Closed,
    Timeout(&'static str),
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Url(error) => write!(f, "invalid Burble endpoint: {error}"),
            Self::WebSocket(error) => write!(f, "WebSocket error: {error}"),
            Self::Json(error) => write!(f, "invalid JSON: {error}"),
            Self::Protocol(message) => write!(f, "Phoenix protocol error: {message}"),
            Self::Rejected { status, response } => {
                write!(f, "Burble rejected the request ({status}): {response}")
            }
            Self::Closed => f.write_str("Burble connection closed"),
            Self::Timeout(operation) => write!(f, "timed out waiting for {operation}"),
        }
    }
}

impl std::error::Error for Error {}

impl From<url::ParseError> for Error {
    fn from(value: url::ParseError) -> Self {
        Self::Url(value)
    }
}

impl From<tokio_tungstenite::tungstenite::Error> for Error {
    fn from(value: tokio_tungstenite::tungstenite::Error) -> Self {
        Self::WebSocket(value)
    }
}

impl From<serde_json::Error> for Error {
    fn from(value: serde_json::Error) -> Self {
        Self::Json(value)
    }
}
