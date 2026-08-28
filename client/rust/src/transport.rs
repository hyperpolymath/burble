// SPDX-License-Identifier: MPL-2.0

use crate::Error;
use futures_util::{SinkExt, StreamExt};
use tokio::net::TcpStream;
use tokio_tungstenite::{MaybeTlsStream, WebSocketStream, connect_async, tungstenite::Message};

/// Reliable ordered text transport used by [`crate::PhoenixClient`].
pub trait TextTransport: Send {
    fn send_text(&mut self, text: String) -> impl Future<Output = Result<(), Error>> + Send;
    fn recv_text(&mut self) -> impl Future<Output = Result<Option<String>, Error>> + Send;
    fn close(&mut self) -> impl Future<Output = Result<(), Error>> + Send;
}

/// Tokio/Tungstenite WebSocket transport supplied with this crate.
pub struct WebSocketTransport {
    socket: WebSocketStream<MaybeTlsStream<TcpStream>>,
}

impl WebSocketTransport {
    pub async fn connect(endpoint: impl AsRef<str>) -> Result<Self, Error> {
        let (socket, _) = connect_async(endpoint.as_ref()).await?;
        Ok(Self { socket })
    }
}

impl TextTransport for WebSocketTransport {
    async fn send_text(&mut self, text: String) -> Result<(), Error> {
        self.socket.send(Message::Text(text.into())).await?;
        Ok(())
    }

    async fn recv_text(&mut self) -> Result<Option<String>, Error> {
        loop {
            match self.socket.next().await {
                Some(Ok(Message::Text(text))) => return Ok(Some(text.to_string())),
                Some(Ok(Message::Close(_))) | None => return Ok(None),
                Some(Ok(_)) => continue,
                Some(Err(error)) => return Err(error.into()),
            }
        }
    }

    async fn close(&mut self) -> Result<(), Error> {
        self.socket.close(None).await?;
        Ok(())
    }
}
