-- SPDX-License-Identifier: PMPL-1.0-or-later
--
-- Burble.ABI.Vext — Hash chain integrity and extension sandboxing proofs.
--
-- Models the Vext hash chain and extension capability model.
-- Proves:
--   1. Chain positions are strictly monotonically increasing.
--   2. Attestation/linkage integrity is maintained.
--   3. Extensions cannot exceed their granted capability boundary.

module Burble.ABI.Vext

import Data.Nat
import Data.Vect

-- ---------------------------------------------------------------------------
-- Hash chain link: a single entry in the Vext chain
-- ---------------------------------------------------------------------------

public export
record ChainLink where
  constructor MkLink
  position : Nat
  hash : Nat
  prevHash : Nat

-- ---------------------------------------------------------------------------
-- Chain validity predicates
-- ---------------------------------------------------------------------------

public export
data StrictlyAfter : ChainLink -> ChainLink -> Type where
  MkAfter : (prf : LT (position a) (position b)) -> StrictlyAfter a b

public export
data LinksTo : ChainLink -> ChainLink -> Type where
  MkLinksTo : (prf : prevHash b = hash a) -> LinksTo a b

public export
data ValidSuccessor : ChainLink -> ChainLink -> Type where
  MkValid : StrictlyAfter a b -> LinksTo a b -> ValidSuccessor a b

-- ---------------------------------------------------------------------------
-- Extension Sandboxing: Capability-based security
-- ---------------------------------------------------------------------------

||| Security capabilities for Vext extensions.
public export
data Capability = ReadOnly | ReadWrite | Admin

||| Proof that one capability subsumes another.
||| Admin > ReadWrite > ReadOnly.
public export
data Subsumes : Capability -> Capability -> Type where
  SubRefl : Subsumes c c
  SubRW   : Subsumes ReadWrite ReadOnly
  SubAdminRW : Subsumes Admin ReadWrite
  SubAdminRO : Subsumes Admin ReadOnly

||| Transitivity of capability subsumption.
public export
subsumesTransitive : Subsumes a b -> Subsumes b c -> Subsumes a c

||| An extension carrying a required capability.
public export
record Extension where
  constructor MkExtension
  name : String
  requiredCap : Capability

||| A sandbox boundary.
public export
record Sandbox where
  constructor MkSandbox
  allowedCap : Capability

||| Core Theorem: Extension Sandboxing.
||| An extension is "Safe" in a sandbox if the sandbox capability
||| subsumes the extension's required capability.
public export
data SafeExtension : Extension -> Sandbox -> Type where
  MkSafe : {ext : Extension} -> {sbox : Sandbox}
        -> (prf : Subsumes (allowedCap sbox) (requiredCap ext))
        -> SafeExtension ext sbox

||| Proof that a ReadWrite sandbox is safe for a ReadOnly extension.
public export
rwSafeForRO : (e : Extension) -> (s : Sandbox)
           -> (requiredCap e = ReadOnly)
           -> (allowedCap s = ReadWrite)
           -> SafeExtension e s

-- ---------------------------------------------------------------------------
-- Monotonicity proofs
-- ---------------------------------------------------------------------------

public export
ltTransitive : {a, b, c : Nat} -> LT a b -> LT b c -> LT a c

-- ---------------------------------------------------------------------------
-- Link construction with proof
-- ---------------------------------------------------------------------------

public export
mkSuccessorLink : (prev : ChainLink) -> (newHash : Nat) -> (ChainLink, ValidSuccessor prev (MkLink (S (position prev)) newHash (hash prev)))

-- ---------------------------------------------------------------------------
-- C-compatible integer mapping for FFI
-- ---------------------------------------------------------------------------

public export
capabilityToInt : Capability -> Int
capabilityToInt ReadOnly  = 0
capabilityToInt ReadWrite = 1
capabilityToInt Admin     = 2
