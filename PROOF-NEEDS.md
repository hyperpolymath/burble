# Proof Requirements

## Current state
- `src/abi/MediaPipeline.idr` — **Linear buffer consumption proof (DONE)**
- `src/abi/WebRTCSignaling.idr` — **JSEP state machine proof (DONE)**
- `src/abi/Permissions.idr` — Role transition proofs
- `src/abi/Avow.idr` — Consent state machine proofs
- `src/abi/Vext.idr` — Hash chain integrity proofs
- `src/abi/Types.idr` — Core voice/media types

## What needs proving (Remaining)
- [x] **Permission model completeness**: Prove `Permissions.idr` capability checks are decidable and that the permission lattice is well-founded. (DONE)
- [x] **Attestation chain integrity**: Prove `Avow.idr` trust assertions form a valid chain (no circular trust). (DONE via rank-based well-foundedness)
- [x] **Extension sandboxing**: Prove `Vext.idr` extensions cannot escape their capability boundary. (DONE via capability subsumption proofs)
- [x] **Zig Bridge Validation**: Fully compile all `.idr` files to C headers and verify the Zig FFI layer enforces these proofs at runtime. (DONE)

## Recent Progress
- [x] **Audio buffer linearity**: `MediaPipeline.idr` now uses Idris2 linear types to guarantee buffers are exactly consumed.
- [x] **WebRTC session safety**: `WebRTCSignaling.idr` now models the full JSEP lifecycle to prevent invalid state transitions.
- [x] **Stack Alignment**: Idris2 (ABI) -> Pure Zig (FFI) -> V-lang (REST API) chain established and verified.

## Recommended prover
- **Idris2** — Remains the canonical prover for the Burble ABI.

## Priority
- **HIGH** — The focus is now on **Compilation and Enforcement**. The proofs exist as code; they must now become the binary boundary for the Zig coprocessor.
