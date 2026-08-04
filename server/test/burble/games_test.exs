# SPDX-License-Identifier: MPL-2.0
#
# Burble.Games — the per-game profile registry. Game-specific behaviour is
# DATA (roles + command→role table + config schema), never code: burble
# relays game payloads verbatim and only ever consults these tables.
defmodule Burble.GamesTest do
  use ExUnit.Case, async: true

  alias Burble.Games

  describe "registry" do
    test "fetches the idaptik profile by id" do
      assert {:ok, Burble.Games.Idaptik} = Games.fetch("idaptik")
    end

    test "an unknown game is :error" do
      assert :error = Games.fetch("pong")
    end
  end

  describe "idaptik profile" do
    test "declares its id and both asymmetric roles" do
      assert Burble.Games.Idaptik.game_id() == "idaptik"
      assert Burble.Games.Idaptik.roles() == ["infiltrator", "hacker"]
    end

    test "routes body verbs to the infiltrator" do
      for tag <- ["SetButton", "Jump", "Interact", "ThrowUsb"] do
        assert Games.sender_for(Burble.Games.Idaptik, tag) == "infiltrator"
      end
    end

    test "routes uplink, pivot AND Net View verbs to the hacker" do
      # NetSsh/NetHack are absent from IDApTIK's own relay table — a live
      # bug this profile fixes (spec: game-session-fabric design).
      for tag <- ["Uplink", "Pivot", "Unpivot", "NetSsh", "NetHack"] do
        assert Games.sender_for(Burble.Games.Idaptik, tag) == "hacker"
      end
    end

    test "session and test immediates belong to either seat" do
      for tag <- ["Pause", "Restart", "ForceCrisis", "ForceExtract", "ForceFail"] do
        assert Games.sender_for(Burble.Games.Idaptik, tag) == :either
      end
    end

    test "an unknown tag is :unknown" do
      assert Games.sender_for(Burble.Games.Idaptik, "BecomeAdmin") == :unknown
    end
  end

  describe "idaptik config schema" do
    test "accepts the canonical run config" do
      assert :ok =
               Burble.Games.Idaptik.validate_config(%{
                 "seed" => 123_456,
                 "difficulty" => "standard",
                 "reduced_motion" => false,
                 "supervised" => true
               })
    end

    test "missing keys take defaults (only seed is required)" do
      assert :ok = Burble.Games.Idaptik.validate_config(%{"seed" => 1})
    end

    test "rejects a non-integer seed, a bad difficulty, and non-map config" do
      assert {:error, reason} = Burble.Games.Idaptik.validate_config(%{"seed" => "abc"})
      assert reason =~ "seed"

      assert {:error, reason} =
               Burble.Games.Idaptik.validate_config(%{"seed" => 1, "difficulty" => "nightmare"})

      assert reason =~ "difficulty"

      assert {:error, _} = Burble.Games.Idaptik.validate_config([])
    end
  end
end
