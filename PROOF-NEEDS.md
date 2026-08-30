# Proof requirements and verified status

## Evidence boundary

Verified on 2026-08-29 with the repository package command:

    just build-proofs

Idris2 type-checked the aggregate module and all nine component modules.
The active Idris2 source contains zero postulate, believe_me, or assert_total
occurrences.

This evidence establishes the stated properties of the Idris2 model only.
It does not establish that the Zig implementation, a SNIF guest, or the BEAM
runtime conforms to that model. Compilation is not runtime proof.

## Confirmed Idris2 properties

- [x] Avow.idr: ranked attestations and noCircularTrust exclude a linked trust
  chain from an identity back to itself.
- [x] Permissions.idr: role-level comparison is decidable; the declared
  escalation/de-escalation witnesses and Owner upper-bound theorem type-check.
  Speaker and LLM share a level, so this is a privilege-level preorder rather
  than a strict total order over distinct role constructors.
- [x] Vext.idr: capability subsumption is decidable and transitive for the
  model; SafeExtension requires a subsumption witness. This does not prove
  that the runtime sandbox enforces the witness.
- [x] WebRTCSignaling.idr: only constructors in ValidTransition can inhabit
  the modelled JSEP transitions; double-offer and return-from-Closed
  inhabitants are excluded.
- [x] MediaPipeline.idr: model buffers are linear and model pipeline stages
  consume them once. The denoise and gain model functions are identity
  transformations, and no executable equivalence to Zig has been proved.
- [x] BleSpa.idr, NearbyPresence.idr, Foreign.idr, and Types.idr type-check as
  part of the same package.
- [x] Burble.ABI is a real package-built aggregate of those nine modules; the
  former unbuildable UniversalABI certificate scaffold was removed.

## Open proof obligations

- [ ] Generate authoritative conformance vectors from the Idris2 model, or use
  another reviewed mechanism, and compare Idris2, Zig, SNIF/WASM, and BEAM
  results.
- [ ] Add a deliberately divergent Zig or WASM fixture that makes the
  conformance gate fail.
- [ ] Prove linear-memory layout, alignment, length, error-code, ownership, and
  lifetime obligations for the SNIF buffer boundary.
- [ ] Build and attest the ReleaseSafe FFT/IFFT/noise-gate/echo-cancel guests.
- [ ] Keep firewall, PTP, QUIC, LMDB, and other host I/O outside SNIF in an
  authenticated least-privilege external service, with timeout and revocation
  tests.
- [ ] Map every active Zig entry point to an Idris2 contract and fail CI on an
  unmapped addition.
- [ ] Add the Idris2 build and escape-hatch scan as a merge gate.
- [ ] Add Creusot contracts and verifier execution for the 57 Rust files
  identified in issue #207. No Rust proof currently exists.
- [ ] Locate or publish and pin the canonical unified Hexadeca adapter
  authority before claiming API conformance.

## Status vocabulary

- Implemented: executable source exists.
- Configured: a build or verifier invocation is wired.
- Type-checked: Idris2 accepted the model and its encoded obligations.
- Conformance-tested: independently implemented layers agree on firing
  fixtures.
- Proved: the named theorem was accepted by the named verifier.

None of these statuses implies the next.
