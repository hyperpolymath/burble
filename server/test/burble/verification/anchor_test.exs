# SPDX-License-Identifier: PMPL-1.0-or-later
#
# Burble Anchor Test — Vext to Blockchain Bridge.

defmodule Burble.Verification.AnchorTest do
  use ExUnit.Case, async: false
  alias Burble.Verification.Vext

  setup do
    # Capture telemetry directly to avoid dependency on global processes
    parent = self()
    handler_id = "vext-test-handler-#{inspect(self())}"
    
    :telemetry.attach(
      handler_id,
      [:burble, :vext, :checkpoint],
      fn _event, measurements, metadata, _config ->
        send(parent, {:vext_checkpoint, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
    
    chain_state = %{
      position: 0,
      latest_hash: "initial_hash"
    }
    
    {:ok, chain_state: chain_state}
  end

  test "Vext checkpoint at position 50 triggers telemetry event", %{chain_state: state} do
    # 1. Create 49 messages (no checkpoint yet)
    {_header, state} = Enum.reduce(1..49, {nil, state}, fn i, {_, acc} ->
      Vext.create_header("msg #{i}", "user1", DateTime.utc_now(), acc)
    end)

    # Verify no telemetry received yet
    refute_receive {:vext_checkpoint, _, _}, 100

    # 2. Create the 50th message
    Vext.create_header("the 50th message", "user1", DateTime.utc_now(), state)

    # 3. Verify telemetry event received
    assert_receive {:vext_checkpoint, %{position: 50}, %{header: header}}, 500
    assert header.chain_position == 50
  end
end
