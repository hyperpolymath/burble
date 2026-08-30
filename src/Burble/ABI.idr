-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- Burble.ABI -- package-built aggregate for the Idris2 ABI model.
--
-- Importing this module proves only that the listed Idris2 definitions and
-- their type-level obligations check together. Runtime conformance of the Zig
-- FFI and future SNIF guests is a separate, currently open obligation.

module Burble.ABI

import public Burble.ABI.Types
import public Burble.ABI.Foreign
import public Burble.ABI.NearbyPresence
import public Burble.ABI.BleSpa
import public Burble.ABI.WebRTCSignaling
import public Burble.ABI.MediaPipeline
import public Burble.ABI.Vext
import public Burble.ABI.Permissions
import public Burble.ABI.Avow

%default total
