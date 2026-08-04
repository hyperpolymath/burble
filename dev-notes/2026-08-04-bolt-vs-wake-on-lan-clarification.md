<!-- SPDX-License-Identifier: MPL-2.0 -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->

# Bolt vs. Wake-on-LAN: what the "poke" actually does

A recurring point of confusion: does `Burble.Bolt` (`server/lib/burble/bolt/`)
let you "wake" a remote machine and launch something on it — e.g. trigger a
game launch on a friend's PC?

**No.** Verified against the current code:

- Bolt is a magic UDP/QUIC datagram (`listener.ex` binds `udp/7373` +
  `udp/9` WoL-compat, optional QUIC) that, on receipt, calls
  `Burble.Bolt.Notify.incoming/2` (`notify.ex`), which broadcasts over
  Phoenix PubSub to `BurbleWeb.BoltChannel` so *already-connected browser
  tabs* render an "Incoming Bolt" call overlay.
- That whole path requires `Burble.Bolt.Listener` to already be a running,
  supervised process inside an already-running Burble instance. There is no
  code path from a Bolt packet to powering on a cold machine, launching the
  Burble application itself, or launching any other application. The
  subsystem's own README (`server/lib/burble/bolt/README.adoc`) already
  says this precisely: it "triggers an incoming-call notification **if
  Burble is running there**" — the WoL comparison is about the *packet
  style* (magic UDP datagram), not the *power state* it can affect.
- There is currently no integration between Bolt and any specific game.
  IDApTIK (`metadatastician/IDApTIK`) has its own, entirely separate
  multiplayer transport and launch path (a Phoenix-relay-based session
  system in its own server, `crates/idaptik-net`), unconnected to Burble.
  IDApTIK's own ADR-0006
  (`docs/adr/0006-gossamer-host-and-burble-transport.md`) explicitly gates
  any Burble transport integration behind unmet preconditions — as of its
  2026-07-21 status note, "burble ships no embeddable non-voice data
  channel (no Rust surface; no `Phoenix.Socket.Transport` adapter; QUIC
  NIFs disabled in the default build)" — and that ADR is about Burble as a
  *data-channel transport* for game traffic, not about Bolt specifically;
  Bolt isn't mentioned there at all.

Summary: **Bolt rings a phone that's already off the hook**, it does not
**plug the phone in**. Real Wake-on-LAN (powering on a suspended/off
machine from its network card) is a different mechanism this codebase does
not implement.
