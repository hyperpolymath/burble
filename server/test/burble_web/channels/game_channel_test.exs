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
