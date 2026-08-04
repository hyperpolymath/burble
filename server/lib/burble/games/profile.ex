# SPDX-License-Identifier: MPL-2.0
#
# Burble.Games.Profile — the contract a game implements to ride burble's
# game-session lane. Everything here is DATA about routing and configuration;
# game truth lives in the peers' own deterministic engines (the fabric spec's
# founding invariant, inherited from IDApTIK ADR-0005).
defmodule Burble.Games.Profile do
  @moduledoc """
  A registered game: its id, seat roles, command routing table, and session
  config schema.

  `command_roles/0` maps a wire command's tag (the `"cmd"` field of the
  game's typed command JSON) to the seat allowed to send it, or `:either`.
  This is routing, not rules — the game's own engine decides what a command
  *does*.
  """

  @callback game_id() :: String.t()
  @callback roles() :: [String.t()]
  @callback command_roles() :: %{String.t() => String.t() | :either}
  @callback validate_config(term()) :: :ok | {:error, String.t()}
end
