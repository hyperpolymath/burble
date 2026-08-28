// SPDX-License-Identifier: MPL-2.0

use crate::{Error, TextTransport};
use serde_json::{Value, json};
use std::{collections::VecDeque, time::Duration};
use tokio::time::{Instant, timeout};

const REPLY_TIMEOUT: Duration = Duration::from_secs(10);
const HEARTBEAT_AFTER: Duration = Duration::from_secs(15);

/// Non-reply message received on the joined channel.
#[derive(Debug, Clone, PartialEq)]
pub struct Broadcast {
    pub event: String,
    pub payload: Value,
}

/// Minimal single-channel implementation of the Phoenix V2 JSON protocol.
pub struct PhoenixClient<T: TextTransport> {
    transport: T,
    topic: Option<String>,
    join_ref: Option<String>,
    next_ref: u64,
    pending: VecDeque<Broadcast>,
    heartbeat_ref: Option<String>,
    last_send: Instant,
}

impl<T: TextTransport> PhoenixClient<T> {
    pub fn new(transport: T) -> Self {
        Self {
            transport,
            topic: None,
            join_ref: None,
            next_ref: 0,
            pending: VecDeque::new(),
            heartbeat_ref: None,
            last_send: Instant::now(),
        }
    }

    fn take_ref(&mut self) -> String {
        self.next_ref += 1;
        self.next_ref.to_string()
    }

    async fn send_frame(
        &mut self,
        join_ref: Option<&str>,
        msg_ref: &str,
        topic: &str,
        event: &str,
        payload: Value,
    ) -> Result<(), Error> {
        let frame = serde_json::to_string(&json!([join_ref, msg_ref, topic, event, payload]))?;
        self.transport.send_text(frame).await?;
        self.last_send = Instant::now();
        Ok(())
    }

    async fn read_frame(&mut self) -> Result<(Option<String>, String, String, Value), Error> {
        let text = self.transport.recv_text().await?.ok_or(Error::Closed)?;
        let value: Value = serde_json::from_str(&text)?;
        let Value::Array(mut parts) = value else {
            return Err(Error::Protocol(format!("frame is not an array: {text}")));
        };
        if parts.len() != 5 {
            return Err(Error::Protocol(format!(
                "frame has {} elements, expected 5",
                parts.len()
            )));
        }
        let payload = parts.pop().expect("length checked");
        let event = take_string(parts.pop().expect("length checked"), "event")?;
        let topic = take_string(parts.pop().expect("length checked"), "topic")?;
        let msg_ref = parts
            .pop()
            .expect("length checked")
            .as_str()
            .map(str::to_owned);
        Ok((msg_ref, topic, event, payload))
    }

    fn classify(
        &mut self,
        (msg_ref, topic, event, payload): (Option<String>, String, String, Value),
    ) -> Result<Classified, Error> {
        match event.as_str() {
            "phx_reply" => {
                if msg_ref
                    .as_ref()
                    .is_some_and(|value| self.heartbeat_ref.as_ref() == Some(value))
                {
                    self.heartbeat_ref = None;
                    return Ok(Classified::Consumed);
                }
                let msg_ref =
                    msg_ref.ok_or_else(|| Error::Protocol("phx_reply has no ref".into()))?;
                let status = payload
                    .get("status")
                    .and_then(Value::as_str)
                    .unwrap_or("")
                    .to_owned();
                let response = payload.get("response").cloned().unwrap_or(Value::Null);
                let response = if status == "ok" {
                    Ok(response)
                } else {
                    Err(Error::Rejected { status, response })
                };
                Ok(Classified::Reply { msg_ref, response })
            }
            "phx_error" => Err(Error::Protocol(format!("channel errored: {payload}"))),
            "phx_close" => Err(Error::Closed),
            _ => {
                if self.topic.as_deref().is_some_and(|joined| joined != topic) {
                    return Ok(Classified::Consumed);
                }
                Ok(Classified::Broadcast(Broadcast { event, payload }))
            }
        }
    }

    async fn await_reply(&mut self, wanted: &str) -> Result<Value, Error> {
        let deadline = Instant::now() + REPLY_TIMEOUT;
        loop {
            let remaining = deadline.saturating_duration_since(Instant::now());
            if remaining.is_zero() {
                return Err(Error::Timeout("Phoenix reply"));
            }
            let frame = timeout(remaining, self.read_frame())
                .await
                .map_err(|_| Error::Timeout("Phoenix reply"))??;
            match self.classify(frame)? {
                Classified::Reply { msg_ref, response } if msg_ref == wanted => return response,
                Classified::Broadcast(message) => self.pending.push_back(message),
                Classified::Reply { .. } | Classified::Consumed => {}
            }
        }
    }

    /// Join one channel topic. A client intentionally owns exactly one topic.
    pub async fn join(&mut self, topic: &str, params: Value) -> Result<Value, Error> {
        if self.topic.is_some() {
            return Err(Error::Protocol("client has already joined a topic".into()));
        }
        let msg_ref = self.take_ref();
        self.send_frame(Some(&msg_ref), &msg_ref, topic, "phx_join", params)
            .await?;
        let response = self.await_reply(&msg_ref).await?;
        self.topic = Some(topic.to_owned());
        self.join_ref = Some(msg_ref);
        Ok(response)
    }

    /// Push an event and return the channel's response.
    pub async fn push(&mut self, event: &str, payload: Value) -> Result<Value, Error> {
        let topic = self
            .topic
            .clone()
            .ok_or_else(|| Error::Protocol("push before join".into()))?;
        let join_ref = self.join_ref.clone();
        let msg_ref = self.take_ref();
        self.send_frame(join_ref.as_deref(), &msg_ref, &topic, event, payload)
            .await?;
        self.await_reply(&msg_ref).await
    }

    /// Wait for the next channel broadcast, maintaining socket heartbeats.
    pub async fn next_broadcast(&mut self, wait: Duration) -> Result<Option<Broadcast>, Error> {
        if let Some(message) = self.pending.pop_front() {
            return Ok(Some(message));
        }
        let deadline = Instant::now() + wait;
        loop {
            if self.heartbeat_ref.is_none() && self.last_send.elapsed() >= HEARTBEAT_AFTER {
                let msg_ref = self.take_ref();
                self.send_frame(None, &msg_ref, "phoenix", "heartbeat", json!({}))
                    .await?;
                self.heartbeat_ref = Some(msg_ref);
            }
            let remaining = deadline.saturating_duration_since(Instant::now());
            if remaining.is_zero() {
                return Ok(None);
            }
            let heartbeat_wait = HEARTBEAT_AFTER.saturating_sub(self.last_send.elapsed());
            let slice = remaining.min(heartbeat_wait.max(Duration::from_millis(50)));
            match timeout(slice, self.read_frame()).await {
                Err(_) => {}
                Ok(frame) => match self.classify(frame?)? {
                    Classified::Broadcast(message) => return Ok(Some(message)),
                    Classified::Reply { .. } | Classified::Consumed => {}
                },
            }
        }
    }

    /// Leave the joined channel and close the WebSocket, best effort.
    pub async fn leave(&mut self) {
        if let (Some(topic), Some(join_ref)) = (self.topic.clone(), self.join_ref.clone()) {
            let msg_ref = self.take_ref();
            let _ = self
                .send_frame(Some(&join_ref), &msg_ref, &topic, "phx_leave", json!({}))
                .await;
        }
        let _ = self.transport.close().await;
    }
}

enum Classified {
    Reply {
        msg_ref: String,
        response: Result<Value, Error>,
    },
    Broadcast(Broadcast),
    Consumed,
}

fn take_string(value: Value, name: &str) -> Result<String, Error> {
    value
        .as_str()
        .map(str::to_owned)
        .ok_or_else(|| Error::Protocol(format!("frame {name} is not a string")))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::{
        collections::VecDeque,
        sync::{Arc, Mutex},
    };

    struct MockTransport {
        sent: Arc<Mutex<Vec<String>>>,
        received: VecDeque<String>,
    }

    impl TextTransport for MockTransport {
        async fn send_text(&mut self, text: String) -> Result<(), Error> {
            self.sent.lock().unwrap().push(text);
            Ok(())
        }
        async fn recv_text(&mut self) -> Result<Option<String>, Error> {
            Ok(self.received.pop_front())
        }
        async fn close(&mut self) -> Result<(), Error> {
            Ok(())
        }
    }

    fn frame(value: Value) -> String {
        serde_json::to_string(&value).unwrap()
    }

    #[tokio::test]
    async fn joins_with_v2_frame_and_returns_response() {
        let sent = Arc::new(Mutex::new(Vec::new()));
        let transport = MockTransport {
            sent: Arc::clone(&sent),
            received: [frame(json!(["1", "1", "game:s", "phx_reply", {
                "status": "ok", "response": {"role": "hacker", "game": "idaptik"}
            }]))]
            .into(),
        };
        let mut client = PhoenixClient::new(transport);
        let reply = client
            .join("game:s", json!({"role": "hacker", "game": "idaptik"}))
            .await
            .unwrap();
        assert_eq!(reply["role"], "hacker");
        assert_eq!(
            serde_json::from_str::<Value>(&sent.lock().unwrap()[0]).unwrap(),
            json!(["1", "1", "game:s", "phx_join", {"role": "hacker", "game": "idaptik"}])
        );
    }

    #[tokio::test]
    async fn buffers_broadcast_that_precedes_reply() {
        let sent = Arc::new(Mutex::new(Vec::new()));
        let transport = MockTransport {
            sent,
            received: [
                frame(json!(["1", null, "game:s", "peer_joined", {"role": "infiltrator"}])),
                frame(json!(["1", "1", "game:s", "phx_reply", {"status": "ok", "response": {}}])),
            ]
            .into(),
        };
        let mut client = PhoenixClient::new(transport);
        client.join("game:s", json!({})).await.unwrap();
        assert_eq!(
            client
                .next_broadcast(Duration::ZERO)
                .await
                .unwrap()
                .unwrap(),
            Broadcast {
                event: "peer_joined".into(),
                payload: json!({"role": "infiltrator"}),
            }
        );
    }

    #[tokio::test]
    async fn exposes_channel_rejection() {
        let transport = MockTransport {
            sent: Arc::new(Mutex::new(Vec::new())),
            received: [frame(json!(["1", "1", "game:s", "phx_reply", {
                "status": "error", "response": {"reason": "unknown game"}
            }]))]
            .into(),
        };
        let mut client = PhoenixClient::new(transport);
        let error = client.join("game:s", json!({})).await.unwrap_err();
        assert!(matches!(error, Error::Rejected { .. }));
        assert!(error.to_string().contains("unknown game"));
    }
}
