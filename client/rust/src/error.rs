// SPDX-License-Identifier: MPL-2.0

use std::fmt;

/// Failure returned by the transport, Phoenix protocol, or Burble channel.
#[derive(Debug)]
pub enum Error {
    Url(url::ParseError),
    WebSocket(tokio_tungstenite::tungstenite::Error),
    /// Failure reported by a caller-supplied [`crate::TextTransport`].
    ///
    /// The bundled WebSocket transport retains its structured `WebSocket`
    /// variant; adapters use this variant instead of mislabelling an I/O
    /// failure as a Phoenix protocol error.
    Transport(Box<dyn std::error::Error + Send + Sync>),
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
            Self::Transport(message) => write!(f, "transport error: {message}"),
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

impl std::error::Error for Error {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Self::Url(error) => Some(error),
            Self::WebSocket(error) => Some(error),
            Self::Transport(error) => Some(error.as_ref()),
            Self::Json(error) => Some(error),
            Self::Protocol(_) | Self::Rejected { .. } | Self::Closed | Self::Timeout(_) => None,
        }
    }
}

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

#[cfg(test)]
mod tests {
    use super::Error;
    use std::io;

    #[test]
    fn adapter_transport_errors_are_not_labelled_as_protocol_failures() {
        let error = Error::Transport(Box::new(io::Error::new(
            io::ErrorKind::BrokenPipe,
            "pipe unavailable",
        )));

        assert_eq!(error.to_string(), "transport error: pipe unavailable");
        let Error::Transport(source) = error else {
            panic!("expected the transport variant");
        };
        let source = source.downcast::<io::Error>().expect("typed source");
        assert_eq!(source.kind(), io::ErrorKind::BrokenPipe);
    }
}
