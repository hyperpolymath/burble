# SPDX-License-Identifier: MPL-2.0
#
# Burble.Games.Idaptik — the IDApTIK Ghost Lobby profile, first consumer of
# the game-session lane. The routing table is ported from IDApTIK's
# session_channel.ex and adds the NetSsh/NetHack hacker verbs missing there
# (a live bug: the hacker's Net View clicks were rejected as unknown).
defmodule Burble.Games.Idaptik do
  @behaviour Burble.Games.Profile

  @difficulties ~w(story standard operator)

  @impl true
  def game_id, do: "idaptik"

  @impl true
  def roles, do: ["infiltrator", "hacker"]

  @impl true
  def command_roles do
    %{
      # The infiltrator's body verbs.
      "SetButton" => "infiltrator",
      "Jump" => "infiltrator",
      "Interact" => "infiltrator",
      "ThrowUsb" => "infiltrator",
      # The hacker's uplink, pivot, and Net View verbs.
      "Uplink" => "hacker",
      "Pivot" => "hacker",
      "Unpivot" => "hacker",
      "NetSsh" => "hacker",
      "NetHack" => "hacker",
      # Session and test immediates — either seat.
      "Pause" => :either,
      "Restart" => :either,
      "ForceCrisis" => :either,
      "ForceExtract" => :either,
      "ForceFail" => :either
    }
  end

  @impl true
  def validate_config(%{} = config) do
    with :ok <- require_integer(config, "seed"),
         :ok <- optional_in(config, "difficulty", @difficulties),
         :ok <- optional_boolean(config, "reduced_motion"),
         :ok <- optional_boolean(config, "supervised") do
      :ok
    end
  end

  def validate_config(_other), do: {:error, "config must be a JSON object"}

  defp require_integer(config, key) do
    case Map.fetch(config, key) do
      {:ok, value} when is_integer(value) -> :ok
      {:ok, _} -> {:error, "#{key} must be an integer"}
      :error -> {:error, "#{key} is required"}
    end
  end

  defp optional_in(config, key, allowed) do
    case Map.fetch(config, key) do
      :error ->
        :ok

      {:ok, value} when is_binary(value) ->
        if value in allowed do
          :ok
        else
          {:error, "#{key} must be one of #{Enum.join(allowed, ", ")}"}
        end

      {:ok, _} ->
        {:error, "#{key} must be a string"}
    end
  end

  defp optional_boolean(config, key) do
    case Map.fetch(config, key) do
      :error -> :ok
      {:ok, value} when is_boolean(value) -> :ok
      {:ok, _} -> {:error, "#{key} must be a boolean"}
    end
  end
end
