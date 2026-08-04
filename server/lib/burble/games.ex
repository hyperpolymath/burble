# SPDX-License-Identifier: MPL-2.0
#
# Burble.Games — compile-time registry of game profiles. Adding a game to
# the platform = implementing Burble.Games.Profile and adding one entry
# here. Runtime registration is deliberately deferred (fabric spec).
defmodule Burble.Games do
  @profiles %{
    "idaptik" => Burble.Games.Idaptik
  }

  @doc "Look up a registered game profile module by its id."
  @spec fetch(String.t()) :: {:ok, module()} | :error
  def fetch(game_id), do: Map.fetch(@profiles, game_id)

  @doc """
  The seat allowed to send a command tag under `profile`: a role string,
  `:either`, or `:unknown` for a tag the game never declared. Public so
  tests and fixture-replaying tools route commands from the correct side
  without duplicating the table (parity with IDApTIK's
  `SessionChannel.sender_for/1`).
  """
  @spec sender_for(module(), String.t()) :: String.t() | :either | :unknown
  def sender_for(profile, cmd_tag) do
    Map.get(profile.command_roles(), cmd_tag, :unknown)
  end
end
