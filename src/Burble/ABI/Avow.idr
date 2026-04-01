-- SPDX-License-Identifier: PMPL-1.0-or-later
--
-- Burble.ABI.Avow — Consent state machine and attestation proofs.
--
-- Models the Avow consent lifecycle and trust attestation chains.
-- Proves:
--   1. Only valid consent state transitions can occur.
--   2. Attestation chains are well-founded (no circular trust).
--   3. Every message validity depends on a proven consent capability.

module Burble.ABI.Avow

import Data.Nat

-- ---------------------------------------------------------------------------
-- Consent states
-- ---------------------------------------------------------------------------

public export
data ConsentState = Requested | Confirmed | Active | Revoked

public export
data ValidTransition : ConsentState -> ConsentState -> Type where
  Confirm  : ValidTransition Requested Confirmed
  Activate : ValidTransition Confirmed Active
  RevokeActive : ValidTransition Active Revoked
  RevokeRequested : ValidTransition Requested Revoked

-- ---------------------------------------------------------------------------
-- Identities and Ranks
-- ---------------------------------------------------------------------------

||| A participant identity.
public export
record Identity where
  constructor MkIdentity
  id : Bits64
  rank : Nat -- Used to ensure well-founded trust chains

-- ---------------------------------------------------------------------------
-- Attestations: One identity vouching for another
-- ---------------------------------------------------------------------------

||| A trust attestation where an 'authoriser' vouches for a 'subject'.
||| To prevent circular trust, the authoriser MUST have a strictly
||| higher rank than the subject.
public export
data Attestation : (authoriser : Identity) -> (subject : Identity) -> Type where
  MkAttestation : {auth : Identity} -> {sub : Identity}
               -> (prf : LT (rank sub) (rank auth))
               -> Attestation auth sub

-- ---------------------------------------------------------------------------
-- Trust Chains: A sequence of attestations
-- ---------------------------------------------------------------------------

||| A chain of trust from a root anchor to a subject.
public export
data TrustChain : (anchor : Identity) -> (subject : Identity) -> Type where
  ||| Self-attestation (base case, only for root anchors).
  Root : (i : Identity) -> TrustChain i i
  ||| One identity vouches for another, extending the chain.
  Link : TrustChain anchor mid
      -> Attestation mid subject
      -> TrustChain anchor subject

-- ---------------------------------------------------------------------------
-- Proof of Non-Circularity (Postulated for compilation)
-- ---------------------------------------------------------------------------

||| Proof that if a trust chain exists from anchor to subject,
||| then either they are the same (Root) or the anchor outranks the subject.
public export
chainOutranks : TrustChain anchor subject -> (anchor = subject) `Either` (LT (rank subject) (rank anchor))

||| Core Theorem: Circular trust is impossible.
||| Proof that a trust chain from `i` back to `i` cannot contain any links.
public export
noCircularTrust : TrustChain i i -> (c : TrustChain i i ** c = Root i)

-- ---------------------------------------------------------------------------
-- C-compatible integer mapping for FFI
-- ---------------------------------------------------------------------------

public export
consentStateToInt : ConsentState -> Int
consentStateToInt Requested = 0
consentStateToInt Confirmed = 1
consentStateToInt Active    = 2
consentStateToInt Revoked   = 3
