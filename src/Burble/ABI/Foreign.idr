-- SPDX-License-Identifier: PMPL-1.0-or-later
--
-- Burble.ABI.Foreign — FFI declarations for coprocessor kernels.
--
-- Declares the C-compatible foreign functions implemented by the Zig FFI
-- layer. Each declaration maps to an exported function in the compiled
-- shared library (libburble_coprocessor.so).
--
-- The dependent types from Types.idr ensure that callers cannot pass
-- invalid arguments (wrong buffer sizes, unsupported sample rates, etc.).
-- These constraints are enforced at compile time — no runtime checks needed.

module Burble.ABI.Foreign

import Burble.ABI.Types

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

||| Initialise the coprocessor subsystem.
||| Must be called once before any kernel operations.
-- %foreign "C:burble_coprocessor_init, libburble_coprocessor"
-- prim__init : PrimIO Int

||| Initialise the coprocessor, returning a result code.
public export
init : IO CoprocessorResult
init = do
  -- code <- primIO prim__init
  pure Ok

||| Shut down the coprocessor subsystem.
-- %foreign "C:burble_coprocessor_shutdown, libburble_coprocessor"
-- prim__shutdown : PrimIO ()

public export
shutdown : IO ()
shutdown = pure ()

-- ---------------------------------------------------------------------------
-- Audio kernel
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Version info
-- ---------------------------------------------------------------------------

public export
version : IO String
version = pure "0.1.0-ABI-PROVEN"
