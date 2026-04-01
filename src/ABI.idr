-- SPDX-License-Identifier: PMPL-1.0-or-later
--
-- Burble ABI — Master entry point for formal proofs.
--
-- This module imports all verified ABI components to ensure they are
-- compiled into a single set of C headers for the Zig FFI layer.

module ABI

import Burble.ABI.Types
import Burble.ABI.Avow
import Burble.ABI.Permissions
import Burble.ABI.Vext
import Burble.ABI.MediaPipeline
import Burble.ABI.WebRTCSignaling
import Burble.ABI.Foreign

main : IO ()
main = do
  putStrLn "Burble ABI Proofs Compiled."
  putStrLn $ "Version: " ++ (unsafePerformIO Foreign.version)
  putStrLn $ "Result Ok: " ++ (show (resultToInt Ok))
  putStrLn $ "State Stable: " ++ (show (signalingStateToInt Stable))
  putStrLn $ "Role Owner: " ++ (show (roleToInt Owner))
