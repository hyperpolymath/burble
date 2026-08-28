# SPDX-License-Identifier: MPL-2.0

defmodule Burble.Bridges.MumbleVarintTest do
  use ExUnit.Case, async: true

  alias Burble.Bridges.MumbleVarint

  test "round-trips every positive encoding width without consuming trailing data" do
    values = [
      0,
      0x7F,
      0x80,
      0x3FFF,
      0x4000,
      0x1F_FFFF,
      0x20_0000,
      0xFFF_FFFF,
      0x1000_0000,
      0xFFFF_FFFF,
      0x1_0000_0000,
      0xFFFF_FFFF_FFFF_FFFF
    ]

    for value <- values do
      encoded = MumbleVarint.encode(value)
      assert {^value, <<0xAA, 0xBB>>} = MumbleVarint.decode(encoded <> <<0xAA, 0xBB>>)
    end
  end

  test "uses Mumble's big-endian prefix encoding rather than protobuf LEB128" do
    assert MumbleVarint.encode(0x80) == <<0x80, 0x80>>
    assert MumbleVarint.encode(0x4000) == <<0xC0, 0x40, 0x00>>
    assert MumbleVarint.encode(0x20_0000) == <<0xE0, 0x20, 0x00, 0x00>>
    assert MumbleVarint.encode(0x1000_0000) == <<0xF0, 0x10, 0x00, 0x00, 0x00>>
  end

  test "rejects truncated and reserved encodings" do
    assert_raise FunctionClauseError, fn -> MumbleVarint.decode(<<0x80>>) end
    assert_raise FunctionClauseError, fn -> MumbleVarint.decode(<<0xF1, 0, 0, 0, 0>>) end
  end
end
