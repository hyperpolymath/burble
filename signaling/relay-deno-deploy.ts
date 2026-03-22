// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Burble Signaling Relay — Deno Deploy version.
// Ephemeral room-name rendezvous. Rooms expire after 60 seconds.
// No data persisted. No accounts. No logs. No tracking.
//
// Deploy: deployctl deploy --project=burble-relay signaling/relay-deno-deploy.ts

const rooms = new Map<string, { data: string; expires: number }>();

// Cleanup expired entries
setInterval(() => {
  const now = Date.now();
  for (const [k, v] of rooms) {
    if (now > v.expires) rooms.delete(k);
  }
}, 10_000);

const cors: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, PUT, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Content-Type": "application/json",
};

Deno.serve((req: Request) => {
  const url = new URL(req.url);

  if (req.method === "OPTIONS") return new Response(null, { headers: cors });

  if (url.pathname === "/" || url.pathname === "/health") {
    return new Response(JSON.stringify({ ok: true, rooms: rooms.size, service: "burble-relay" }), { headers: cors });
  }

  const match = url.pathname.match(/^\/room\/([a-zA-Z0-9_-]+)\/(offer|answer)$/);
  if (!match) {
    return new Response(JSON.stringify({ error: "not found", usage: "PUT/GET /room/:name/offer or /room/:name/answer" }), { status: 404, headers: cors });
  }

  const [, name, type] = match;
  const key = `${name}:${type}`;

  // PUT — store with 60s TTL
  if (req.method === "PUT") {
    return req.text().then(body => {
      rooms.set(key, { data: body, expires: Date.now() + 60_000 });
      return new Response(JSON.stringify({ ok: true, room: name, type }), { headers: cors });
    });
  }

  // GET — single check (client polls)
  if (req.method === "GET") {
    const entry = rooms.get(key);
    if (entry && Date.now() < entry.expires) {
      const data = entry.data;
      if (type === "answer") rooms.delete(key); // one-shot
      return new Response(data, { headers: cors });
    }
    return new Response(JSON.stringify({ error: "not ready" }), { status: 404, headers: cors });
  }

  return new Response(JSON.stringify({ error: "method not allowed" }), { status: 405, headers: cors });
});
