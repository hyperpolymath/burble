<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# Burble Proof Status

**Short version (verified 2026-08-29, Idris2 0.7.0).** **All 9 package
modules compile and type-check**: `Types`, `Foreign`, `NearbyPresence`,
`BleSpa`, `WebRTCSignaling`, `MediaPipeline`, `Vext`, `Permissions`, and
`Avow`. The `BleSpa` constant references were qualified so Idris2 does not
implicitly rebind their lowercase names. `just build-proofs` succeeds. Per
ADR-0007 this is type-check-level design assurance; runtime conformance of the
Zig/SNIF implementation remains an open proof obligation.

## Current ABI proofs (all compile)

| Module | File |
|---|---|
| Types | `src/Burble/ABI/Types.idr` |
| Foreign | `src/Burble/ABI/Foreign.idr` |
| NearbyPresence | `src/Burble/ABI/NearbyPresence.idr` |
| BleSpa (wire layout + rendezvous state machine) | `src/Burble/ABI/BleSpa.idr` |
| Permissions | `src/Burble/ABI/Permissions.idr` |
| Avow (attestation chain non-circularity) | `src/Burble/ABI/Avow.idr` |
| Vext (hash chain + capability subsumption) | `src/Burble/ABI/Vext.idr` |
| MediaPipeline (linear buffer consumption) | `src/Burble/ABI/MediaPipeline.idr` |
| WebRTCSignaling (JSEP state machine) | `src/Burble/ABI/WebRTCSignaling.idr` |

## Dangerous-pattern debt

- 0 `postulate`, 0 `believe_me`, 0 `assert_total`

## Proof gaps (enforcement, not typecheck)

These modules **compile** but their *runtime enforcement* is incomplete — see `STATE.a2ml [blockers-and-issues]`:

- **Avow** — `server/lib/burble/verification/avow.ex` is data-type-only. No dependent-type verification at runtime. Phase 1 replaces with hash-chain audit log + property test.
- **LLM** — no `LLM.idr` proof of frame protocol well-formedness. Phase 2 target.
- **Timing** — no `Timing.idr` proof of best-source monotonicity. Phase 4 target.
- **SNIF buffer ABI** — guest artifacts and model↔Zig↔WASM conformance are not
  established. Idris type-checking does not prove the runtime boundary.
- **Rust/Creusot** — the 57 tracked Rust files have no Creusot contracts or
  verifier execution. Ordinary Rust tests are not a proof (issue #207).

## History

The former aggregate `src/Burble/ABI.idr` was not in the package and failed
when checked directly because it imported a nonexistent `UniversalABI`.
Its certificate/report scaffold was therefore not proof evidence. The
aggregate is now a package-built public import of the nine component modules.

## Phase 0 build-proofs status

**Package file:** `src/Burble/ABI/burble-abi.ipkg` (added 2026-05-10)

**Justfile recipe:** `just build-proofs` — runs `idris2 --build burble-abi.ipkg` from `src/Burble/ABI/`

**Module-name collision decision:** `src/interface/abi/Types.idr` also declares `module Burble.ABI.Types`.
This causes an Idris2 package collision if both trees share a `sourcedir`.
Phase 0 resolution: `burble-abi.ipkg` builds only `src/Burble/ABI/` (the canonical tree).
The `src/interface/abi/` tree is marked **deferred to Phase 1 module-path cleanup**.

**Modules compiled by `just build-proofs`:**

| Module | Status |
|---|---|
| `Burble.ABI` | Compiles as the package aggregate; contains no certificate or runtime-conformance claim |
| `Burble.ABI.Types` | Compiles (imports: `Data.Fin`, `Data.Vect`) |
| `Burble.ABI.Foreign` | Compiles (imports: `Burble.ABI.Types`; live `%foreign` declarations) |
| `Burble.ABI.Avow` | Compiles (imports: `Data.Nat`; non-circularity theorem proven) |
| `Burble.ABI.Permissions` | Compiles (imports: `Data.Nat`; role-hierarchy proofs) |
| `Burble.ABI.Vext` | Compiles (imports: `Data.Nat`, `Data.Vect`; chain monotonicity proofs) |
| `Burble.ABI.MediaPipeline` | Compiles (imports: `Burble.ABI.Types`, `Data.Vect`; no postulate) |
| `Burble.ABI.WebRTCSignaling` | Compiles (imports: none extra; JSEP state machine proofs) |
| `Burble.ABI.NearbyPresence` | Compiles (presence-zone invariants) |
| `Burble.ABI.BleSpa` | Compiles (24-byte layout and transition exclusions) |

**Postulate debt:** none in the package modules. Runtime implementation
conformance is separate and remains open; no direct NIF may be used to close it.

**Unsafe FFI debt:**
- `prim__registerCallback` in `Burble.ABI.Foreign` is intentionally unexposed. C→Idris callbacks require `believe_me` casts (tracked upstream in idris2#3182). Phase 0 replaces callback usage with `pollEvents` (lock-free ring buffer polling). No `believe_me` or `assert_total` in any module.

**Local verifier result (2026-08-29):** `just build-proofs` type-checked the
aggregate and all nine components. This is Idris2 model evidence only, not
Zig/SNIF/runtime conformance.

## Phase 0 deploy-smoke status (Workstream 0.4)

**Status: UNBLOCKED** — 2026-05-12

Workstream 0.4 (container stack smoke test) was previously blocked because
`podman-compose` is Python (banned by the hyperpolymath language policy) and
no TOML-native alternative existed.

**selur-compose v0.1.0** (Rust, TOML-native) is now functionally complete:

- 216 tests passing across five crates (`schema`, `interp`, `plan`, `driver`, binary)
- `cargo build --workspace` succeeds
- `just up` and `just down` in the burble Justfile are wired to
  `tools/selur-compose/target/release/selur-compose -f containers/compose.toml up -d`
- The binary is built on demand by `just deploy` (or `just build-selur-compose`)

**To run the deploy smoke test:**

```bash
just deploy
# → builds selur-compose (~3 min, one-time)
# → brings up containers/compose.toml stack
# → server: http://localhost:4000, web: http://localhost:8080

just down
# → tears down the stack cleanly
```

**Remaining blocker for full CI validation:** selur-compose v0.1.0 has not yet
been tagged and published to GitHub (pending maintainer tag action). Once
`v0.1.0` is pushed to `github.com/hyperpolymath/selur-compose`, the
`tools/selur-compose/` directory becomes a proper submodule and CI can run
`just deploy` as a smoke step.

See `.machine_readable/integrations/selur-compose.a2ml` for the canonical
integration manifest.
