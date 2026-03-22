// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Burble Signaling Relay — Cloudflare Worker version.
//
// Deploy: wrangler deploy signaling/worker.js --name burble-relay
// Or via dashboard: paste this into a new Worker.
//
// Uses Cloudflare KV for ephemeral storage (60s TTL).
// Free tier: 100K reads/day, 1K writes/day — more than enough.
//
// Requires KV namespace binding: ROOMS
// wrangler kv namespace create ROOMS
// Then add to wrangler.toml:
//   [[kv_namespaces]]
//   binding = "ROOMS"
//   id = "<your-namespace-id>"

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const cors = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, PUT, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
      "Content-Type": "application/json",
    };

    if (request.method === "OPTIONS") return new Response(null, { headers: cors });

    if (url.pathname === "/health") {
      return new Response(JSON.stringify({ ok: true, edge: request.cf?.colo }), { headers: cors });
    }

    const match = url.pathname.match(/^\/room\/([a-zA-Z0-9_-]+)\/(offer|answer)$/);
    if (!match) {
      return new Response(JSON.stringify({ error: "not found" }), { status: 404, headers: cors });
    }

    const [, name, type] = match;
    const key = `${name}:${type}`;

    // PUT — store with 60s TTL
    if (request.method === "PUT") {
      const body = await request.text();
      await env.ROOMS.put(key, body, { expirationTtl: 60 });
      return new Response(JSON.stringify({ ok: true, room: name, type }), { headers: cors });
    }

    // GET — fetch (single attempt, client retries)
    if (request.method === "GET") {
      const data = await env.ROOMS.get(key);
      if (data) {
        if (type === "answer") await env.ROOMS.delete(key); // one-shot
        return new Response(data, { headers: cors });
      }
      return new Response(JSON.stringify({ error: "not ready" }), { status: 404, headers: cors });
    }

    return new Response(JSON.stringify({ error: "method not allowed" }), { status: 405, headers: cors });
  }
};
