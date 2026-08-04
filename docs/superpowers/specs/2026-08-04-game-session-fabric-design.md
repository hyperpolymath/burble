<!-- SPDX-License-Identifier: MPL-2.0 -->
<!-- SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk> -->

# Burble game-session fabric — design

**Date:** 2026-08-04
**Status:** Approved by owner (brainstorming session, IDApTIK context)
**First consumer:** IDApTIK Ghost Lobby two-human netplay
**Related:** IDApTIK ADR-0002 (multiplayer transport), ADR-0005 (session relay
topology), ADR-0006 (gossamer host / burble transport); burble ADR-0013
(embeddability); `game-server-admin` `INTENT.contractile` (GSA is admin, not
matchmaking).

## Context

IDApTIK already has CI-gated two-seat netplay: `idaptik-netplay --interactive`
is a live delay-lockstep seat with the full TUI face, and the Elixir relay in
`IDApTIK/server/` relays the typed `Command`/`Event` stream verbatim between
the infiltrator and hacker seats. Game truth is peer-equal by construction —
both seats run the identical deterministic sim; the relay carries intent and
never interprets it. Loss, rejoin, and snapshot resync are proven by a
byte-identical four-leg loopback gate.

What is missing is the *human* layer: a reachable meeting point, in-band
session/config agreement (today both seats must share an identical script file
out-of-band), a coordination surface, and voice. The owner has ruled:

1. **Burble is the estate's gaming communication platform** — the session
   fabric ships inside burble, now, not in a new repo and not inside IDApTIK.
   When burble's native client and data channel are complete, burble is the
   game's *primary communication method* (the ADR-0006 `BurbleTransport`
   end-state).
2. **Not IDApTIK-specific** — lobby/session/relay/comms is a general gaming
   capability; the game-specific part must be data (a role table + config
   schema), not code.
3. **Host-first topology** — either player hosts burble and the other
   connects; the same artifact can be parked on a server later.
4. **Lobby-list session discovery** — create with settings, browse, join.
5. **Coordination v1** — canned signals, free-text chat, and structured
   pause/readiness etiquette, all as a frontend-only lane that can never
   contaminate the deterministic sim artifacts.

## Architecture

Burble's Phoenix server gains a **game-session lane** beside its existing
`room:` (presence/chat/voice) and `signaling:` (WebRTC) channels:

- **`game:<session_id>` channel** — the verbatim typed relay, ported from
  IDApTIK's `session_channel.ex`: byte-preserving JSON relay of `command`
  (tagged `"cmd"`) and `event` (tagged `"event"`) payloads, optional integer
  `seq` envelope with stale/duplicate drop, `peer_joined`/`peer_left`
  broadcasts. Burble reads only the tag, never the payload. Authorization is a
  routing table over the tag, looked up from the session's registered game
  profile.
- **Game profiles as data** — behaviour `Burble.Games.Profile`: `game_id`,
  `roles` (list of seat names), `command_roles` (tag → role | `:either`), and
  a config schema (validate/1 on opaque JSON). Profiles are compiled in; the
  first is `Burble.Games.Idaptik` carrying the current IDApTIK table **plus
  the `NetSsh`/`NetHack` entries missing from it today** (a live bug: the
  hacker's Net View verbs are rejected as unknown commands by the current
  IDApTIK relay). Runtime profile registration is deliberately deferred — a
  second game adds one module.
- **Session registry + lobby** — a supervised registry (GenServer + monitors,
  single-node) holding session descriptors:
  `{session_id, game_id, config, seats: role → open|taken, voice: {room_id,
  join_code}, created_at}`. A `lobby` channel exposes `create_session`
  (game_id, config, creator's role) → `{session, join_code}` and
  `list_sessions`, and broadcasts `session_opened` / `seat_taken` /
  `session_closed`. Config is validated against the profile schema at create
  time; **the joiner adopts the session's config in-band**, which retires the
  shared-script-file requirement. For IDApTIK the config is
  `{seed, difficulty, reduced_motion, supervised}`.
- **Comms = the paired room** — creating a game session creates/pairs a
  burble room under the same id (burble's existing room-per-id +
  instant-connect code model; its integration comment already names IDApTIK).
  Chat uses burble's existing room events. A small typed **`signal`** room
  event is added: `wait | go | abort | mark(target) | pause_request |
  pause_accept`, each one keypress in the client, rendered in the peer's log
  pane. Pause etiquette is client-side convention: the sim's `Pause` command
  (either-seat, unchanged) is sent only after an accepted `pause_request`.
  Browser clients get WebRTC voice in the same room immediately; native seats
  gain voice when the native client lands.
- **One socket** — Phoenix multiplexes channels, so a native seat holds one
  WebSocket carrying `game:<id>` + `room:<id>` (+ `lobby` pre-game). Auth is
  burble's existing guest JWT (REST guest auth, then socket token).
- **Bolt = instant invite** — burble's existing UDP/7373 knock
  (`Burble.Bolt`, CLI `burble bolt <ip|user@domain|--broadcast>`, standalone,
  NAPTR/SRV discovery, WoL-compatible, QUIC-authenticated when available)
  carries an arbitrary JSON payload, so a **`game_invite` bolt** carries
  `{game_id, session_id, join_code, host_url}` end-to-end. Flow: host creates
  the session, bolts the friend (LAN broadcast needs no address at all); the
  friend's client surfaces "incoming game invite — join?"; one keypress runs
  guest auth against `host_url` and seats them. The lobby list is the browse
  path; Bolt is the direct-summon path. The netplay client gains its own
  small invite listener (native seats must work without a browser); it lands
  in the lobby slice.
- **Determinism is untouched** — sims remain authoritative on both seats;
  burble relays verbatim; comms ride a separate lane that never enters the
  sim; the byte-identical loopback gate is the acceptance bar for the port.

### What this deliberately does not do

- No game logic, scoring, or tick math in burble (IDApTIK ADR-0005 invariant,
  inherited).
- No matchmaking in `game-server-admin` — GSA administers the burble process
  (its `profiles/burble.a2ml` already exists); it does not broker games.
- No gossamer involvement — gossamer is client-side shell/packaging; nothing
  server-side.
- No native voice in v1 — gated on burble's native client / data channel
  milestones. The Rust `SessionTransport` seam in `idaptik-net` is the
  declared `BurbleTransport` swap point when that lands.

## Rust client (`idaptik-net`)

- `PhoenixClient` learns the burble socket (endpoint path + token param) and
  multi-channel join over one socket.
- A `Comms` trait (send/receive signal + chat) with the burble-room
  implementation; rendered into the TUI log pane; a chat input mode that does
  not steal gameplay keys.
- `idaptik-netplay` gains pre-game lobby screens: connect → guest auth →
  create/browse/join → wait-for-peer → live. Config comes from the session
  descriptor, not a local script file (scripted/CI mode keeps the file).

## Rollout — each slice an independently verifiable PR chain

1. **burble: game lane** — `Burble.Games` behaviour + Idaptik profile +
   `game:` channel at parity with IDApTIK's `session_channel.ex`, mix channel
   tests ported and extended (role enforcement incl. NetSsh/NetHack, seq
   dedup, unknown-command/unknown-game errors).
2. **idaptik-net: point at burble** — socket/auth support; run the four-leg
   loopback gate (batch determinism, loss, live determinism, resync — plus
   the supervised leg) against a burble instance in CI. **Green here is the
   acceptance bar for the port.**
3. **Lobby + Bolt invites** — registry + `lobby` channel + tests
   (create/join/seat-conflict/session-full/stale cleanup via monitors + TTL);
   netplay lobby UI + in-band config adoption; `game_invite` bolt payload +
   client invite listener (accept → auth → seat).
4. **Comms** — `signal` room event + client UI; a live loopback leg with
   comms traffic running proves the determinism artifacts stay
   byte-identical.
5. **Lite host + packaging** — a verified host profile that runs game
   sessions with just the BEAM release: VeriSimDB degrade (`offline_ok`)
   exercised by test, voice-optional (no coturn required); host guide for
   LAN and tunneled internet play; GSA profile touch-up.
6. **Retirement** — once the gate is green against burble in both repos' CI,
   IDApTIK's `server/` is removed; IDApTIK ADR-0002/0005/0006 gain
   amendments recording burble as the session fabric.

## Error handling

Typed error replies on every refusal: unknown game, invalid config (schema
violation), role taken, session full, unknown command tag, wrong-role
command, stale seq (acknowledged, dropped, not relayed — networks duplicate).
Lite mode: VeriSimDB unreachable degrades per `offline_ok` and is tested;
abrupt peer disconnect follows the existing loss → hold → rejoin → resync
flow, which must pass unchanged against burble.

## Risks

- **Burble main health**: PRs #178–180 are queued (owner-gated merges;
  #180's own test suite currently red on the bebop flip); two install
  workflows red on main. The game lane touches none of that surface, but the
  repo's merge bottleneck is real.
- **VeriSimDB weight**: lite-host mode is a work item with tests, not an
  assumption.
- **Cross-repo CI**: slice 2 needs a burble instance in IDApTIK's CI (pinned
  ref or container image) — the same shape as today's in-repo relay boot in
  `loopback_check.sh`, but heavier.
