<!-- SPDX-License-Identifier: MPL-2.0 -->
<!-- SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk> -->

# Game-Session Lane (Slice 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Burble gains a `game:<session_id>` channel — a verbatim typed
command/event relay with per-game role tables as data — at behavioural parity
with IDApTIK's `session_channel.ex`, proven by ported + extended mix channel
tests.

**Architecture:** A `Burble.Games.Profile` behaviour makes the game-specific
part pure data (roles, command→role table, config schema);
`Burble.Games.Idaptik` is the first profile. `BurbleWeb.GameChannel` relays
`command`/`event` payloads byte-preserving between the two seats of
`game:<session_id>`, authorizing only by the payload's tag against the
session's profile, with optional strictly-increasing `seq` dedup. Burble
never interprets game payloads (IDApTIK ADR-0005 invariant, inherited).
Until the lobby slice lands, the joining client names its game in the join
params; the lobby later becomes the authority and the param a cross-check.

**Tech Stack:** Elixir/Phoenix channels (`use Phoenix.Channel`), ExUnit +
`Phoenix.ChannelTest`. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-08-04-game-session-fabric-design.md`
(this plan implements rollout slice 1 only).

## Global Constraints

- Every new `.ex`/`.exs` file starts with `# SPDX-License-Identifier: MPL-2.0`
  on **line 1** (repo licence gate).
- No game logic, scoring, or tick math in burble — the channel reads only the
  `"cmd"`/`"event"` tag, never the payload body, and relays byte-preserving.
- Channel tests: `use ExUnit.Case, async: false` + `use Phoenix.ChannelTest`
  + `@endpoint BurbleWeb.Endpoint`, with the `ensure_started` setup pattern
  from `server/test/burble_web/channels/room_channel_text_test.exs` (shared
  named processes are why `async: false`).
- All mix commands run from `server/` (`cd server && mix test …`).
- `mix format` before every commit; commits are conventional style and signed
  off (`git commit -s`).
- Work happens on branch `feat/game-session-lane` cut from `origin/main`
  (the checkout usually sits on an unrelated feature branch — do not build on
  it).

## Deliberate deviations from `session_channel.ex` (record, don't "fix")

1. The legacy freeform `intent` / `hacker_action` handlers are **not
   ported** — they predate the typed stream and no Rust client sends them.
   The typed `command`/`event` lanes are the whole surface.
2. The IDApTIK table gains `NetSsh` and `NetHack` (hacker verbs) — their
   absence in IDApTIK's relay is a live bug the spec calls out.
3. Join requires `"game"` alongside `"role"` (multi-game platform; profile
   lookup replaces the hardcoded table).

---

### Task 1: `Burble.Games` — profile behaviour, IDApTIK profile, registry

**Files:**
- Create: `server/lib/burble/games/profile.ex`
- Create: `server/lib/burble/games/idaptik.ex`
- Create: `server/lib/burble/games.ex`
- Test: `server/test/burble/games_test.exs`

**Interfaces:**
- Consumes: nothing (leaf module).
- Produces (used by Task 2+):
  - `Burble.Games.fetch(game_id :: String.t()) :: {:ok, module()} | :error`
  - `Burble.Games.sender_for(module(), cmd_tag :: String.t()) ::
     String.t() | :either | :unknown`
  - `profile.game_id() :: String.t()`, `profile.roles() :: [String.t()]`,
    `profile.command_roles() :: %{String.t() => String.t() | :either}`,
    `profile.validate_config(map()) :: :ok | {:error, String.t()}`

- [ ] **Step 1: Write the failing test**

Create `server/test/burble/games_test.exs`:

```elixir
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd server && mix test test/burble/games_test.exs`
Expected: FAIL — `Burble.Games` is not available (module undefined).

- [ ] **Step 3: Implement the behaviour, profile, and registry**

Create `server/lib/burble/games/profile.ex`:

```elixir
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
```

Create `server/lib/burble/games/idaptik.ex`:

```elixir
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
      :error -> :ok
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
```

Create `server/lib/burble/games.ex`:

```elixir
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd server && mix test test/burble/games_test.exs`
Expected: PASS (all tests).

- [ ] **Step 5: Format and commit**

```bash
cd server && mix format
cd .. && git add server/lib/burble/games server/lib/burble/games.ex server/test/burble/games_test.exs
git commit -s -m "feat(games): profile behaviour + registry, IDApTIK first

Game-specific behaviour as data: roles, command->role routing table,
config schema. The IDApTIK table adds the NetSsh/NetHack hacker verbs
missing from its own relay (fabric spec slice 1)."
```

---

### Task 2: `BurbleWeb.GameChannel` — join, peer announcements, socket registration

**Files:**
- Create: `server/lib/burble_web/channels/game_channel.ex`
- Modify: `server/lib/burble_web/channels/user_socket.ex` (add one
  `channel` line after the `signaling:*` line)
- Test: `server/test/burble_web/channels/game_channel_test.exs`

**Interfaces:**
- Consumes: `Burble.Games.fetch/1`, `profile.roles()` (Task 1).
- Produces: topic `game:<session_id>`, join params
  `%{"role" => role, "game" => game_id}`, join reply
  `%{role: role, game: game_id}`; broadcasts `"peer_joined"` /
  `"peer_left"` with `%{"role" => role}`; socket assigns `:role`,
  `:game`, `:profile`, `:last_seq` (Tasks 3–5 rely on these assigns).

- [ ] **Step 1: Write the failing test**

Create `server/test/burble_web/channels/game_channel_test.exs`:

```elixir
# SPDX-License-Identifier: MPL-2.0
#
# BurbleWeb.GameChannel — join/announce tests, ported from IDApTIK's
# session_channel_test.exs (the parity source, per the fabric spec) and
# extended for the multi-game platform shape (join names its game).
#
# async: false — shares the named endpoint/PubSub with the other channel
# suites, mirroring room_channel_text_test.exs.
defmodule BurbleWeb.Channels.GameChannelTest do
  use ExUnit.Case, async: false
  use Phoenix.ChannelTest

  import Burble.TestHelpers

  alias BurbleWeb.GameChannel

  @endpoint BurbleWeb.Endpoint

  setup do
    Application.ensure_all_started(:phoenix_pubsub)
    ensure_started({Phoenix.PubSub, name: Burble.PubSub})

    case BurbleWeb.Endpoint.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    :ok
  end

  defp game_socket do
    socket(BurbleWeb.UserSocket, nil, %{
      user_id: "test-user-#{System.unique_integer([:positive])}",
      display_name: "TestSeat",
      is_guest: true
    })
  end

  defp join!(session, role, game \\ "idaptik") do
    {:ok, reply, socket} =
      game_socket()
      |> subscribe_and_join(GameChannel, "game:" <> session, %{
        "role" => role,
        "game" => game
      })

    {reply, socket}
  end

  describe "join" do
    test "accepts each role and announces it to the peer" do
      {reply, _infil} = join!("j1", "infiltrator")
      assert reply == %{role: "infiltrator", game: "idaptik"}

      {reply, _hacker} = join!("j1", "hacker")
      assert reply == %{role: "hacker", game: "idaptik"}
      assert_broadcast "peer_joined", %{"role" => "hacker"}
    end

    test "rejects a join without a role" do
      assert {:error, %{reason: reason}} =
               game_socket()
               |> subscribe_and_join(GameChannel, "game:j2", %{"game" => "idaptik"})

      assert reason =~ "role"
    end

    test "rejects a role the game does not declare" do
      assert {:error, %{reason: reason}} =
               game_socket()
               |> subscribe_and_join(GameChannel, "game:j3", %{
                 "role" => "billy",
                 "game" => "idaptik"
               })

      assert reason =~ "role"
    end

    test "rejects an unknown game" do
      assert {:error, %{reason: reason}} =
               game_socket()
               |> subscribe_and_join(GameChannel, "game:j4", %{
                 "role" => "infiltrator",
                 "game" => "pong"
               })

      assert reason =~ "unknown game"
    end

    test "rejects a join without a game" do
      assert {:error, %{reason: reason}} =
               game_socket()
               |> subscribe_and_join(GameChannel, "game:j5", %{"role" => "hacker"})

      assert reason =~ "game"
    end

    test "a leaving peer is announced" do
      {_reply, infil} = join!("j6", "infiltrator")
      {_reply, _hacker} = join!("j6", "hacker")
      assert_broadcast "peer_joined", %{"role" => "hacker"}

      Process.unlink(infil.channel_pid)
      leave(infil)
      assert_broadcast "peer_left", %{"role" => "infiltrator"}
    end
  end

  describe "ping" do
    test "answers pong" do
      {_reply, socket} = join!("p1", "hacker")
      ref = push(socket, "ping", %{})
      assert_reply ref, :ok, %{"pong" => true}
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd server && mix test test/burble_web/channels/game_channel_test.exs`
Expected: FAIL — `BurbleWeb.GameChannel` is not available.

- [ ] **Step 3: Implement the channel and register it**

Create `server/lib/burble_web/channels/game_channel.ex`:

```elixir
# SPDX-License-Identifier: MPL-2.0
#
# BurbleWeb.GameChannel — one game session's typed relay lane.
#
# The two seats of `game:<session_id>` exchange their game's typed wire
# enums verbatim: a `"command"` or `"event"` message's payload IS the
# game's JSON, byte-preserving — burble reads only the routing tag and
# never interprets the body. Which seat may send which command tag comes
# from the session's registered game profile (Burble.Games), so this
# module contains no game-specific code at all.
#
# Ported from IDApTIK's session_channel.ex (the parity source; see
# docs/superpowers/specs/2026-08-04-game-session-fabric-design.md).
# Until the lobby slice lands, the joining client names its game in the
# join params; the lobby then becomes the authority and this param a
# cross-check.
defmodule BurbleWeb.GameChannel do
  use Phoenix.Channel

  alias Burble.Games

  @impl true
  def join("game:" <> _session_id, %{"role" => role, "game" => game_id}, socket)
      when is_binary(role) and is_binary(game_id) do
    case Games.fetch(game_id) do
      {:ok, profile} ->
        if role in profile.roles() do
          socket =
            socket
            |> assign(:role, role)
            |> assign(:game, game_id)
            |> assign(:profile, profile)
            |> assign(:last_seq, nil)

          send(self(), :after_join)
          {:ok, %{role: role, game: game_id}, socket}
        else
          {:error,
           %{reason: "unknown role #{inspect(role)} — #{game_id} seats: " <>
               Enum.join(profile.roles(), ", ")}}
        end

      :error ->
        {:error, %{reason: "unknown game: #{inspect(game_id)}"}}
    end
  end

  def join("game:" <> _session_id, params, _socket) do
    missing =
      ["role", "game"]
      |> Enum.reject(&Map.has_key?(params, &1))
      |> Enum.join(" and ")

    {:error, %{reason: "join requires #{missing}"}}
  end

  @impl true
  def handle_info(:after_join, socket) do
    broadcast_from!(socket, "peer_joined", %{"role" => socket.assigns.role})
    {:noreply, socket}
  end

  # Lightweight liveness check.
  @impl true
  def handle_in("ping", _payload, socket) do
    {:reply, {:ok, %{"pong" => true}}, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    if socket.joined do
      broadcast_from!(socket, "peer_left", %{"role" => socket.assigns.role})
    end

    :ok
  end
end
```

Modify `server/lib/burble_web/channels/user_socket.ex` — after the line
`channel "signaling:*", BurbleWeb.SignalingChannel` add:

```elixir
  channel "game:*", BurbleWeb.GameChannel
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd server && mix test test/burble_web/channels/game_channel_test.exs`
Expected: PASS.

- [ ] **Step 5: Run the whole channel suite (no regressions), format, commit**

Run: `cd server && mix test test/burble_web/channels/`
Expected: PASS (all files).

```bash
cd server && mix format
cd .. && git add server/lib/burble_web/channels/game_channel.ex \
  server/lib/burble_web/channels/user_socket.ex \
  server/test/burble_web/channels/game_channel_test.exs
git commit -s -m "feat(game-lane): game:<session_id> channel — join, peers, ping

Role and game validated against the registered profile; peer_joined/
peer_left announcements; no game-specific code in the channel."
```

---

### Task 3: Command relay — verbatim, role-enforced, seq-deduped

**Files:**
- Modify: `server/lib/burble_web/channels/game_channel.ex` (add the
  `handle_in("command", …)` clauses and private helpers before `terminate/2`)
- Test: `server/test/burble_web/channels/game_channel_test.exs` (append
  describes)

**Interfaces:**
- Consumes: `Games.sender_for/2` (Task 1); assigns `:profile`, `:role`,
  `:last_seq` (Task 2).
- Produces: `"command"` handle_in — replies
  `{:ok, %{"relayed" => true}}` | `{:ok, %{"relayed" => false, "reason" =>
  "stale_or_duplicate"}}` | `{:error, %{"reason" => …}}`; broadcasts
  `"command"` with the payload minus `"seq"`. (Task 5's fixture test and
  slice 2's Rust client depend on these exact shapes.)

- [ ] **Step 1: Write the failing tests**

Append to `server/test/burble_web/channels/game_channel_test.exs` (inside
the module, after the `ping` describe):

```elixir
  describe "command relay" do
    test "delivers a hacker Pivot to the infiltrator verbatim" do
      {_reply, _infil} = join!("c1", "infiltrator")
      {_reply, hacker} = join!("c1", "hacker")

      payload = %{"cmd" => "Pivot", "target" => "Bridge"}
      ref = push(hacker, "command", payload)
      assert_reply ref, :ok, %{"relayed" => true}
      assert_push "command", ^payload
    end

    test "delivers the hacker's Net View verbs (absent from the old IDApTIK table)" do
      {_reply, _infil} = join!("c2", "infiltrator")
      {_reply, hacker} = join!("c2", "hacker")

      for payload <- [
            %{"cmd" => "NetSsh", "node" => 0},
            %{"cmd" => "NetHack", "node" => 3}
          ] do
        ref = push(hacker, "command", payload)
        assert_reply ref, :ok, %{"relayed" => true}
        assert_push "command", ^payload
      end
    end

    test "delivers infiltrator body verbs to the hacker verbatim" do
      {_reply, infil} = join!("c3", "infiltrator")

      payload = %{"cmd" => "SetButton", "button" => "Right", "down" => true}
      ref = push(infil, "command", payload)
      assert_reply ref, :ok, %{"relayed" => true}
      assert_broadcast "command", ^payload
    end

    test "either seat may send session immediates" do
      {_reply, infil} = join!("c4", "infiltrator")
      {_reply, hacker} = join!("c4", "hacker")

      for {sender, payload} <- [
            {infil, %{"cmd" => "Pause", "on" => true}},
            {hacker, %{"cmd" => "Restart"}},
            {infil, %{"cmd" => "ForceExtract", "method" => "ServiceExit"}}
          ] do
        ref = push(sender, "command", payload)
        assert_reply ref, :ok, %{"relayed" => true}
        assert_broadcast "command", ^payload
      end
    end
  end

  describe "role enforcement" do
    test "the infiltrator cannot pivot" do
      {_reply, infil} = join!("r1", "infiltrator")

      ref = push(infil, "command", %{"cmd" => "Pivot", "target" => "GridJump"})
      assert_reply ref, :error, %{"reason" => reason}
      assert reason =~ "hacker"
      refute_broadcast "command", _
    end

    test "the hacker has no body" do
      {_reply, hacker} = join!("r2", "hacker")

      for payload <- [
            %{"cmd" => "Jump"},
            %{"cmd" => "Interact"},
            %{"cmd" => "ThrowUsb"},
            %{"cmd" => "SetButton", "button" => "Left", "down" => true}
          ] do
        ref = push(hacker, "command", payload)
        assert_reply ref, :error, %{"reason" => reason}
        assert reason =~ "infiltrator"
      end

      refute_broadcast "command", _
    end

    test "an unknown or untagged command is refused, not relayed" do
      {_reply, hacker} = join!("r3", "hacker")

      ref = push(hacker, "command", %{"cmd" => "BecomeAdmin"})
      assert_reply ref, :error, %{"reason" => reason}
      assert reason =~ "unknown command"

      ref = push(hacker, "command", %{"target" => "Bridge"})
      assert_reply ref, :error, %{"reason" => reason2}
      assert reason2 =~ "cmd"

      ref = push(hacker, "command", "not-a-map")
      assert_reply ref, :error, %{"reason" => reason3}
      assert reason3 =~ "object"

      refute_broadcast "command", _
    end
  end

  describe "sequence handling" do
    test "a duplicate command is acknowledged but dropped, and seq is stripped" do
      {_reply, hacker} = join!("s1", "hacker")
      payload = %{"cmd" => "Unpivot", "seq" => 7}

      ref = push(hacker, "command", payload)
      assert_reply ref, :ok, %{"relayed" => true}
      assert_broadcast "command", %{"cmd" => "Unpivot"} = relayed
      refute Map.has_key?(relayed, "seq")

      ref = push(hacker, "command", payload)
      assert_reply ref, :ok, %{"relayed" => false, "reason" => "stale_or_duplicate"}
      refute_broadcast "command", _
    end

    test "an out-of-order command is acknowledged but dropped" do
      {_reply, hacker} = join!("s2", "hacker")

      ref = push(hacker, "command", %{"cmd" => "Pivot", "target" => "IspOps", "seq" => 5})
      assert_reply ref, :ok, %{"relayed" => true}
      assert_broadcast "command", %{"cmd" => "Pivot"}

      ref = push(hacker, "command", %{"cmd" => "Unpivot", "seq" => 3})
      assert_reply ref, :ok, %{"relayed" => false}
      refute_broadcast "command", _
    end

    test "each seat's sequence is independent" do
      {_reply, infil} = join!("s3", "infiltrator")
      {_reply, hacker} = join!("s3", "hacker")

      ref = push(hacker, "command", %{"cmd" => "Unpivot", "seq" => 9})
      assert_reply ref, :ok, %{"relayed" => true}

      ref = push(infil, "command", %{"cmd" => "Jump", "seq" => 1})
      assert_reply ref, :ok, %{"relayed" => true}
    end
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd server && mix test test/burble_web/channels/game_channel_test.exs`
Expected: the new describes FAIL (no `handle_in("command", …)` clause —
Phoenix crashes the channel or replies with a function-clause error); the
Task-2 describes still PASS.

- [ ] **Step 3: Implement the command lane**

In `server/lib/burble_web/channels/game_channel.ex`, add after the
`handle_in("ping", …)` clause (order within the module: join clauses,
handle_info, ping, command clauses, terminate, private helpers):

```elixir
  # A typed game command (tagged "cmd") -> the other seat, verbatim except
  # for the optional "seq" relay-envelope key.
  def handle_in("command", payload, socket) when is_map(payload) do
    with {:ok, tag} <- command_tag(payload, socket.assigns.profile),
         :ok <- authorize(tag, socket) do
      case note_seq(payload, socket) do
        {:fresh, socket} ->
          broadcast_from!(socket, "command", Map.delete(payload, "seq"))
          {:reply, {:ok, %{"relayed" => true}}, socket}

        {:stale, socket} ->
          # A duplicate or out-of-order send is a fact of networks, not a
          # protocol violation: acknowledge it, drop it, relay nothing.
          {:reply, {:ok, %{"relayed" => false, "reason" => "stale_or_duplicate"}}, socket}
      end
    else
      {:error, reason} -> {:reply, {:error, %{"reason" => reason}}, socket}
    end
  end

  def handle_in("command", _payload, socket) do
    {:reply, {:error, %{"reason" => "command payload must be a JSON object"}}, socket}
  end
```

And the private helpers (before the final `end`, after `terminate/2`):

```elixir
  # -- helpers ---------------------------------------------------------------

  defp command_tag(%{"cmd" => tag}, profile) when is_binary(tag) do
    if Map.has_key?(profile.command_roles(), tag) do
      {:ok, tag}
    else
      {:error, "unknown command: #{inspect(tag)}"}
    end
  end

  defp command_tag(_payload, _profile),
    do: {:error, "command payload must carry the \"cmd\" tag"}

  defp authorize(tag, socket) do
    role = socket.assigns.role

    case Burble.Games.sender_for(socket.assigns.profile, tag) do
      :either -> :ok
      ^role -> :ok
      owner -> {:error, "#{tag} is a #{owner} command (you joined as #{role})"}
    end
  end

  # Track the optional "seq" envelope: a fresh (strictly increasing) integer
  # relays; a duplicate or out-of-order one drops gracefully. Commands
  # without "seq" are always fresh — ordering is then the transport's.
  defp note_seq(%{"seq" => seq}, socket) when is_integer(seq) do
    case socket.assigns.last_seq do
      last when is_integer(last) and seq <= last -> {:stale, socket}
      _ -> {:fresh, assign(socket, :last_seq, seq)}
    end
  end

  defp note_seq(_payload, socket), do: {:fresh, socket}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd server && mix test test/burble_web/channels/game_channel_test.exs`
Expected: PASS (all describes).

- [ ] **Step 5: Format and commit**

```bash
cd server && mix format
cd .. && git add server/lib/burble_web/channels/game_channel.ex \
  server/test/burble_web/channels/game_channel_test.exs
git commit -s -m "feat(game-lane): verbatim command relay — profile-routed, seq-deduped

Byte-preserving relay of the game's typed command JSON; authorization
is a lookup in the session's profile table; optional strictly
increasing seq drops duplicates gracefully."
```

---

### Task 4: Event relay

**Files:**
- Modify: `server/lib/burble_web/channels/game_channel.ex` (two clauses
  between the command clauses and `terminate/2`)
- Test: `server/test/burble_web/channels/game_channel_test.exs` (append)

**Interfaces:**
- Consumes: Task 2 assigns.
- Produces: `"event"` handle_in — reply `{:ok, %{"relayed" => true}}` |
  `{:error, %{"reason" => …}}`; broadcast `"event"` verbatim. (Task 5 and
  the slice-2 lockstep cross-feed depend on this.)

- [ ] **Step 1: Write the failing tests**

Append to the test module:

```elixir
  describe "event relay" do
    test "delivers a typed Event to the other seat verbatim" do
      {_reply, _infil} = join!("e1", "infiltrator")
      {_reply, hacker} = join!("e1", "hacker")

      payload = %{"event" => "PivotOpened", "host" => "ops.isp.net", "hops" => 1}
      ref = push(hacker, "event", payload)
      assert_reply ref, :ok, %{"relayed" => true}
      assert_push "event", ^payload
    end

    test "an untagged event is refused" do
      {_reply, hacker} = join!("e2", "hacker")

      ref = push(hacker, "event", %{"hops" => 1})
      assert_reply ref, :error, %{"reason" => reason}
      assert reason =~ "event"
      refute_broadcast "event", _
    end
  end
```

- [ ] **Step 2: Run to verify the new describes fail**

Run: `cd server && mix test test/burble_web/channels/game_channel_test.exs`
Expected: the two event tests FAIL; everything else PASSES.

- [ ] **Step 3: Implement**

Add to `game_channel.ex`, after the second `handle_in("command", …)`
clause:

```elixir
  # A typed game Event (tagged "event") -> the other seat, verbatim.
  # Events are produced by the peers' deterministic engines, not authored
  # by a seat, so both roles may publish them (lockstep cross-feed).
  def handle_in("event", %{"event" => tag} = payload, socket) when is_binary(tag) do
    broadcast_from!(socket, "event", payload)
    {:reply, {:ok, %{"relayed" => true}}, socket}
  end

  def handle_in("event", _payload, socket) do
    {:reply, {:error, %{"reason" => "event payload must carry the \"event\" tag"}}, socket}
  end
```

- [ ] **Step 4: Run to verify everything passes**

Run: `cd server && mix test test/burble_web/channels/game_channel_test.exs`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
cd server && mix format
cd .. && git add server/lib/burble_web/channels/game_channel.ex \
  server/test/burble_web/channels/game_channel_test.exs
git commit -s -m "feat(game-lane): verbatim event relay"
```

---

### Task 5: Cross-language fixture pass-through

**Files:**
- Create: `server/test/fixtures/game_session/idaptik/commands.json`
  (copied verbatim from the IDApTIK repo,
  `fixtures/session_relay/commands.json`)
- Create: `server/test/fixtures/game_session/idaptik/events.json`
  (copied verbatim from `fixtures/session_relay/events.json`)
- Test: `server/test/burble_web/channels/game_channel_test.exs` (append)

**Interfaces:**
- Consumes: `Games.sender_for/2`, the `"command"`/`"event"` lanes.
- Produces: the vendored wire fixtures later reused by the slice-2 Rust
  round-trip.

- [ ] **Step 1: Vendor the fixtures**

```bash
mkdir -p server/test/fixtures/game_session/idaptik
cp ../IDApTIK/fixtures/session_relay/commands.json \
   server/test/fixtures/game_session/idaptik/commands.json
cp ../IDApTIK/fixtures/session_relay/events.json \
   server/test/fixtures/game_session/idaptik/events.json
```

(If the relative path differs on the executing machine, the source repo is
`metadatastician/IDApTIK`, files `fixtures/session_relay/{commands,events}.json`
— copy at the ref currently on its `main`. JSON carries no comment syntax;
provenance is recorded in the test below.)

- [ ] **Step 2: Write the failing tests**

Append to the test module:

```elixir
  # The cross-language wire fixtures are vendored VERBATIM from the IDApTIK
  # repo (fixtures/session_relay/*.json), where the Rust side round-trips
  # the same files (crates/idaptik-core/tests/session_relay_fixture.rs).
  # If they drift, slice 2's Rust-vs-burble parity run will say so.
  describe "cross-language fixture pass-through" do
    @fixtures Path.expand("../../fixtures/game_session/idaptik", __DIR__)

    defp fixture!(name) do
      @fixtures |> Path.join(name) |> File.read!() |> Jason.decode!()
    end

    test "every fixture Command relays byte-preserving from its allowed seat" do
      {_reply, infil} = join!("f1", "infiltrator")
      {_reply, hacker} = join!("f1", "hacker")
      assert_broadcast "peer_joined", %{"role" => "hacker"}

      for command <- fixture!("commands.json") do
        sender =
          case Burble.Games.sender_for(Burble.Games.Idaptik, command["cmd"]) do
            "infiltrator" -> infil
            "hacker" -> hacker
            :either -> hacker
          end

        ref = push(sender, "command", command)
        assert_reply ref, :ok, %{"relayed" => true}
        assert_broadcast "command", ^command
      end
    end

    test "every captured Event relays byte-preserving" do
      {_reply, _infil} = join!("f2", "infiltrator")
      {_reply, hacker} = join!("f2", "hacker")
      assert_broadcast "peer_joined", %{"role" => "hacker"}

      for event <- fixture!("events.json") do
        ref = push(hacker, "event", event)
        assert_reply ref, :ok, %{"relayed" => true}
        assert_push "event", ^event
      end
    end
  end
```

- [ ] **Step 3: Run — expect pass (the lanes exist); investigate any failure**

Run: `cd server && mix test test/burble_web/channels/game_channel_test.exs`
Expected: PASS. A failure here is signal, not noise — most likely a fixture
command whose tag is missing from the profile table (that is exactly the
NetSsh/NetHack class of bug this suite exists to catch). Fix the profile
table, never the fixture.

- [ ] **Step 4: Run the full server suite**

Run: `cd server && mix test`
Expected: no regressions vs the branch point (pre-existing failures on
`main`, if any, are not yours — compare with a `git stash`-clean run if in
doubt).

- [ ] **Step 5: Format and commit**

```bash
cd server && mix format
cd .. && git add server/test/fixtures/game_session \
  server/test/burble_web/channels/game_channel_test.exs
git commit -s -m "test(game-lane): IDApTIK cross-language wire fixtures pass through verbatim"
```

---

### Task 6: Protocol documentation + PR

**Files:**
- Modify: `docs/PROTOCOL.md` (new section, after the existing channel
  documentation)

**Interfaces:**
- Consumes: everything above.
- Produces: the wire contract slice 2's Rust client pins against.

- [ ] **Step 1: Document the game lane**

Append to `docs/PROTOCOL.md` (match the document's existing heading style):

```markdown
## Game-session lane (`game:<session_id>`)

The game-session fabric's relay lane (see
`docs/superpowers/specs/2026-08-04-game-session-fabric-design.md`). One
topic per session; the two seats exchange their game's typed wire enums
verbatim. Burble reads only the routing tag and never interprets payloads.

**Join** — params `{"role": <seat>, "game": <game_id>}`; both are
validated against the registered game profile (`Burble.Games`). Reply:
`{"role": ..., "game": ...}`. Broadcasts `peer_joined` / `peer_left`
with `{"role": ...}`. Until the lobby ships, the client names its game
here; afterwards the session registry is the authority and this param a
cross-check.

**`command`** — payload is the game's command JSON (tagged `"cmd"`),
relayed byte-preserving to the other seat minus the optional integer
`"seq"` envelope key. Authorization is the profile's tag→seat table.
Replies: `{"relayed": true}` on relay; `{"relayed": false, "reason":
"stale_or_duplicate"}` when `seq` is not strictly increasing for this
seat (acknowledged, dropped, not relayed); `{"reason": ...}` errors for
unknown/untagged/wrong-seat commands.

**`event`** — payload is the game's event JSON (tagged `"event"`),
relayed verbatim; either seat may publish (the peers' deterministic
engines produce events, seats do not author them).

**`ping`** — replies `{"pong": true}`.

First registered profile: `idaptik` (roles `infiltrator`/`hacker`).
```

- [ ] **Step 2: Full-suite sanity + format check**

Run: `cd server && mix test && mix format --check-formatted`
Expected: PASS / no formatting diffs.

- [ ] **Step 3: Commit and open the PR**

```bash
git add docs/PROTOCOL.md
git commit -s -m "docs(protocol): document the game-session lane"
git push -u origin feat/game-session-lane
gh pr create --title "feat: game-session lane — game:<id> channel with per-game profiles (fabric slice 1)" \
  --body "Slice 1 of docs/superpowers/specs/2026-08-04-game-session-fabric-design.md (#181): Burble.Games profile behaviour + IDApTIK profile (adds the NetSsh/NetHack verbs missing from IDApTIK's own relay), game:<session_id> verbatim typed relay at parity with IDApTIK's session_channel.ex, mix suite ported + extended, cross-language wire fixtures vendored, PROTOCOL.md updated. Next slice: point idaptik-net at burble and run the four-leg loopback determinism gate against it."
```

---

## Self-review notes (completed)

- **Spec coverage (slice 1 only):** profile behaviour ✓ (Task 1), Idaptik
  profile incl. NetSsh/NetHack ✓ (Task 1), `game:` channel parity ✓ (Tasks
  2–4: join/peers/ping, command relay + roles + seq, event relay), tests
  ported and extended ✓ (Tasks 2–5), config schema present-but-unused until
  the lobby ✓ (Task 1, by design). Lobby/registry, Bolt invites, comms,
  Rust client, lite-host are later slices — out of scope here.
- **Deliberate omissions recorded:** legacy `intent`/`hacker_action` not
  ported (pre-typed relics, no client sends them).
- **Type consistency:** `Games.fetch/1` → `{:ok, module()} | :error` and
  `Games.sender_for/2` → role | `:either` | `:unknown` used identically in
  Tasks 1, 3, and 5; reply shapes in Task 3's code match Task 3/5 tests.
