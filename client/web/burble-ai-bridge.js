// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Burble AI Bridge — connects Claude Code to the P2P data channel.
//
// Run this in Deno alongside p2p-voice.html to give Claude programmatic
// access to the WebRTC data channel. Exposes a local HTTP API that Claude
// can call via shell commands (curl).
//
// Architecture:
//   Claude Code ←→ HTTP localhost:6474 ←→ this bridge ←→ WebSocket ←→ p2p-voice.html ←→ WebRTC ←→ remote peer
//
// The bridge talks to p2p-voice.html via a tiny WebSocket relay injected
// into the page. Messages flow:
//   curl POST /send → bridge → WS → page → DataChannel → remote page → WS → bridge → curl GET /recv

const PORT = 6474;
const messageQueue = [];
let wsClient = null;

// HTTP server for Claude to interact with
Deno.serve({ port: PORT, hostname: "127.0.0.1" }, async (req) => {
  const url = new URL(req.url);

  // Send a message to the remote peer
  if (req.method === "POST" && url.pathname === "/send") {
    const body = await req.json();
    if (wsClient?.readyState === 1) {
      wsClient.send(JSON.stringify({ type: "send", payload: body }));
      return new Response(JSON.stringify({ ok: true }), { headers: { "Content-Type": "application/json" } });
    }
    return new Response(JSON.stringify({ ok: false, error: "not connected" }), { status: 503, headers: { "Content-Type": "application/json" } });
  }

  // Receive messages from remote peer (poll)
  if (req.method === "GET" && url.pathname === "/recv") {
    const msgs = messageQueue.splice(0);
    return new Response(JSON.stringify({ messages: msgs }), { headers: { "Content-Type": "application/json" } });
  }

  // Check status
  if (req.method === "GET" && url.pathname === "/status") {
    return new Response(JSON.stringify({
      connected: wsClient?.readyState === 1,
      queued: messageQueue.length,
      port: PORT,
    }), { headers: { "Content-Type": "application/json" } });
  }

  // Health
  if (url.pathname === "/health") {
    return new Response("ok");
  }

  return new Response("Burble AI Bridge\n\nPOST /send — send JSON to remote peer\nGET /recv — poll received messages\nGET /status — connection status\n", { status: 200 });
});

// WebSocket server for p2p-voice.html to connect to
Deno.serve({ port: PORT + 1, hostname: "127.0.0.1" }, (req) => {
  if (req.headers.get("upgrade") !== "websocket") {
    return new Response("WebSocket only", { status: 400 });
  }
  const { socket, response } = Deno.upgradeWebSocket(req);

  socket.onopen = () => {
    wsClient = socket;
    console.log("[Burble AI Bridge] Page connected via WebSocket");
  };

  socket.onmessage = (ev) => {
    try {
      const msg = JSON.parse(ev.data);
      if (msg.type === "received") {
        // Message from remote peer, queue for Claude to poll
        messageQueue.push(msg.payload);
        console.log("[Burble AI Bridge] ← Remote:", JSON.stringify(msg.payload));
      }
    } catch (e) {
      console.error("[Burble AI Bridge] Parse error:", e);
    }
  };

  socket.onclose = () => {
    wsClient = null;
    console.log("[Burble AI Bridge] Page disconnected");
  };

  return response;
});

console.log(`[Burble AI Bridge] HTTP API on http://localhost:${PORT}`);
console.log(`[Burble AI Bridge] WebSocket relay on ws://localhost:${PORT + 1}`);
console.log("");
console.log("Claude can now:");
console.log(`  curl -X POST http://localhost:${PORT}/send -d '{"type":"hello","from":"claude"}'`);
console.log(`  curl http://localhost:${PORT}/recv`);
console.log(`  curl http://localhost:${PORT}/status`);
