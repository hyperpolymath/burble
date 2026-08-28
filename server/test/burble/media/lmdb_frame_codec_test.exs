# SPDX-License-Identifier: MPL-2.0

defmodule Burble.Media.LMDBFrameCodecTest do
  use ExUnit.Case, async: true

  alias Burble.Media.LMDBFrameCodec

  test "decodes a valid stored audio frame" do
    encoded = :erlang.term_to_binary({42, 1_000_000, <<1, 2, 3>>})
    assert LMDBFrameCodec.decode(encoded) == {:ok, {42, 1_000_000, <<1, 2, 3>>}}
  end

  test "rejects malformed binaries and invalid frame shapes" do
    assert LMDBFrameCodec.decode(<<0, 1, 2>>) == :not_found
    assert LMDBFrameCodec.decode(:erlang.term_to_binary({-1, 0, <<>>})) == :not_found
    assert LMDBFrameCodec.decode(:erlang.term_to_binary({0, -1, <<>>})) == :not_found
    assert LMDBFrameCodec.decode(:erlang.term_to_binary({0, 0, :not_audio})) == :not_found
  end

  test "safe decoding rejects executable external terms" do
    encoded_fun = :erlang.term_to_binary(fn -> :unsafe end)
    assert LMDBFrameCodec.decode(encoded_fun) == :not_found
  end
end
