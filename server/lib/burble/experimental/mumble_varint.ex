# SPDX-License-Identifier: MPL-2.0

defmodule Burble.Bridges.MumbleVarint do
  @moduledoc false

  import Bitwise

  @spec encode(non_neg_integer()) :: binary()
  def encode(value) when value < 0x80, do: <<value>>

  def encode(value) when value < 0x4000 do
    <<bor(value >>> 8, 0x80), value &&& 0xFF>>
  end

  def encode(value) when value < 0x20_0000 do
    <<bor(value >>> 16, 0xC0), value >>> 8 &&& 0xFF, value &&& 0xFF>>
  end

  def encode(value) when value < 0x1000_0000 do
    <<bor(value >>> 24, 0xE0), value >>> 16 &&& 0xFF, value >>> 8 &&& 0xFF, value &&& 0xFF>>
  end

  def encode(value) when value < 0x1_0000_0000, do: <<0xF0, value::32-big>>
  def encode(value) when value <= 0xFFFF_FFFF_FFFF_FFFF, do: <<0xF4, value::64-big>>

  @spec decode(binary()) :: {non_neg_integer(), binary()}
  def decode(<<0::1, value::7, rest::binary>>), do: {value, rest}

  def decode(<<0b10::2, high::6, low::8, rest::binary>>) do
    {high <<< 8 ||| low, rest}
  end

  def decode(<<0b110::3, high::5, low::16-big, rest::binary>>) do
    {high <<< 16 ||| low, rest}
  end

  def decode(<<0b1110::4, high::4, low::24-big, rest::binary>>) do
    {high <<< 24 ||| low, rest}
  end

  def decode(<<0xF0, value::32-big, rest::binary>>), do: {value, rest}
  def decode(<<0xF4, value::64-big, rest::binary>>), do: {value, rest}
end
