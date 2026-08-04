# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

defmodule Burble.BebopDecodeError do
  @moduledoc """
  Raised by the generated Bebop decoders (`Burble.Protocol.*`) when wire input
  is truncated or malformed: a length prefix that exceeds the bytes present, a
  short fixed-width field, a bool byte that is neither 0 nor 1, or an unknown
  enum value.

  Strictness is the point — before 2026-08 the generated decoders defaulted on
  malformed input (a truncated frame decoded to a valid-looking EMPTY message,
  caught by CI on the drift gate's first run). Decoders now reject instead.

  This module lives OUTSIDE `lib/burble/protocol/` on purpose: everything in
  that directory is generated and byte-checked against `mix bebop.generate`
  output (scripts/check-bebop-codegen.sh Check B), while this exception is
  hand-maintained shared infrastructure.
  """

  defexception [:message]
end
