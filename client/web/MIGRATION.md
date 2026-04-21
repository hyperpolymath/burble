# AffineScript Migration

## Status

An incremental migration from ReScript (`.res`) to AffineScript (`.affine`) is underway.
The AffineScript compiler is not yet available; **ReScript remains authoritative** for all
runtime behaviour until the compiler lands.  The `.affine` files are design stubs —
they document the intended resource-ownership model and serve as templates for the
eventual compile step.

Every stub carries this header:

```
// STUB — awaiting AffineScript compiler; ReScript version is authoritative until migration completes
```

Do not delete or modify the corresponding `.res` files while the compiler is unavailable.

---

## Phase 5 — EASY tier stubs (completed 2026-04-21)

The five smallest ReScript files now have companion `.affine` stubs:

| ReScript source | AffineScript stub | Notes |
|---|---|---|
| `src/Bindings.res` | `src/Bindings.affine` | DOM handle types marked `affine`; `appendChild` child param marked `linear` (transferred into DOM) |
| `src/Room.res` | `src/Room.affine` | Pure string utilities; `isValidRoomName` name param marked `affine` |
| `src/Main.res` | `src/Main.affine` | `app` marked `linear` (created once, never dropped); pop-state callback marked `affine` |
| `src/Audio.res` | `src/Audio.affine` | `AudioContext` marked `linear`; `analyzer_state` marked `affine`; `stream` param `linear` (consumed) |
| `src/Signaling.res` | `src/Signaling.affine` | SDP values `affine` (sent once); Phoenix `socket` `linear`; `channel` `affine` (join once) |

Each stub carries a `@migrate_from("...")` annotation pointing back to its source file.

---

## Annotation conventions

| Qualifier | Meaning |
|---|---|
| `linear T` | Value must be consumed **exactly once** (no drop, no duplicate) |
| `affine T` | Value may be consumed **at most once** (can be dropped, cannot be duplicated) |
| (no qualifier) | Unrestricted / borrowed — safe to share and ignore |

Parameters in `fn` signatures follow the same conventions:

```affine
fn createAnalyzer: (linear stream: RTC.stream) => affine analyzer_state
//                  ^^^^^^ consumed by callee    ^^^^^ caller must use result
```

---

## How to regenerate or update stubs

Until an AffineScript compiler ships, stubs are written by hand following this process:

1. Read the `.res` file in full.
2. Copy each `type`, `external`, and top-level `let`/`fn` declaration.
3. Change `let` to `fn` for function declarations whose bodies will be in AffineScript.
4. Add `linear` to parameters representing **uniquely-owned resources** (streams, contexts,
   sockets, channels) that the callee is expected to take full ownership of.
5. Add `affine` to parameters representing **single-use values** (SDP blobs, callbacks
   registered once, DOM nodes being transferred).
6. Add `affine` or `linear` to the return type where the caller receives ownership.
7. Mark resource-holding record types with `type affine …` or `type linear …`.
8. Add the `@migrate_from("…")` annotation at the top.
9. Add the STUB header comment.

There is no automated tooling yet.  Track stubs alongside the corresponding `.res` files
in git so diffs are reviewable.

---

## Remaining files

30 files remain across the MEDIUM and HARD tiers of the Haiku inventory.  A rough
breakdown (subject to re-assessment as the compiler spec matures):

### MEDIUM tier (~15 files)
These have moderate complexity — state machines, async flows, or non-trivial data
structures — but no deeply entangled side effects:

- `src/WebRTC.res` — peer-connection lifecycle (many linear resources)
- `src/App.res` — application state record
- `src/Routes.res` — URL parsing and routing
- `src/AuthState.res` — authentication state machine
- `src/Render.res` — virtual DOM diffing helpers
- `src/Codec.res` — encode/decode utilities
- `src/Config.res` — runtime configuration
- `src/Ice.res` — ICE candidate handling
- `src/Channel.res` — DataChannel management
- `src/Peer.res` — peer state container
- `src/UI.res` — UI component helpers
- `src/Logger.res` — structured logging
- `src/Timer.res` — timeout/interval wrappers
- `src/Events.res` — internal event bus
- `src/Storage.res` — localStorage abstraction

### HARD tier (~15 files)
These involve complex resource graphs, callbacks across module boundaries, or
runtime JS interop that requires careful affine modelling:

- `src/Connection.res` — full WebRTC connection state machine
- `src/Media.res` — MediaStream acquisition and track management
- `src/Bridge.res` — AI bridge WebSocket client
- `src/Negotiation.res` — SDP offer/answer negotiation loop
- `src/IceGathering.res` — ICE gathering with trickle support
- `src/DataChannel.res` — DataChannel open/message/close lifecycle
- `src/VoiceActivity.res` — VAD with audio pipeline
- `src/Network.res` — fetch wrappers with retry logic
- `src/Session.res` — session bootstrap and teardown
- `src/Room/State.res` — room state reducer
- `src/Room/View.res` — room rendering pipeline
- `src/AI.res` — AI channel protocol handler
- `src/Crypto.res` — key generation and DTLS helpers
- `src/Diagnostics.res` — connection diagnostics
- `src/Teardown.res` — clean shutdown sequencing (all linear resources freed)

---

## Related

- `CLAUDE.md` — project overview and Burble architecture
- Individual `.affine` files in `src/` — the stubs themselves
