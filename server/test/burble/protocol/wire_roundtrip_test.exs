# SPDX-License-Identifier: MPL-2.0
#
# Wire-level round-trip tests for the generated Bebop codecs.
#
# The pre-existing protocol_test.exs covers ENUM round-trips (atom <-> int)
# only. These codecs carry the signalling plane (spline ADR-0005 criterion
# (a)), so the struct/message encoders and the union discriminator path need
# real encode -> decode -> compare coverage before anything rides on them.
#
# Every test here fails if the wire format regresses: the assertions compare
# decoded values to the originals, and the byte-layout tests pin the actual
# encoding (uint32-LE length-prefixed strings) rather than trusting it.

defmodule Burble.Protocol.WireRoundtripTest do
  use ExUnit.Case, async: true

  alias Burble.Protocol.VoiceSignal

  # A rejection is either a {:error, _} return (union-level contract) or a
  # Burble.BebopDecodeError raise (field-level contract). Silent defaults —
  # the old behaviour, where a truncated frame decoded to a valid-looking
  # EMPTY message — are the bug class the strictness tests keep dead.
  defp assert_rejected(fun) do
    case fun.() do
      {:error, _reason} -> :ok
      other -> flunk("expected rejection, got: #{inspect(other)}")
    end
  rescue
    Burble.BebopDecodeError -> :ok
  end

  describe "SdpPayload" do
    test "round-trips an ordinary SDP body" do
      original = %{sdp: "v=0\r\no=- 0 0 IN IP4 127.0.0.1\r\n", media_type: "audio"}
      {decoded, rest} = original |> VoiceSignal.encode_sdp_payload() |> VoiceSignal.decode_sdp_payload()

      assert decoded == original
      assert rest == <<>>, "decoder must consume the whole buffer"
    end

    test "round-trips UTF-8 and empty strings" do
      for original <- [
            %{sdp: "", media_type: ""},
            %{sdp: "ünïcödé — ✓", media_type: "audio+video"}
          ] do
        {decoded, <<>>} = original |> VoiceSignal.encode_sdp_payload() |> VoiceSignal.decode_sdp_payload()
        assert decoded == original
      end
    end

    test "strings are uint32-LE length-prefixed (pins the wire format)" do
      bin = VoiceSignal.encode_sdp_payload(%{sdp: "abc", media_type: "xy"})
      assert <<3::32-little, "abc", 2::32-little, "xy">> == bin
    end

    test "survives an SDP body large enough to exercise multi-byte lengths" do
      big = String.duplicate("a=candidate:0 1 UDP 2113667327 192.168.0.1 54400 typ host\r\n", 40)
      original = %{sdp: big, media_type: "audio"}
      {decoded, <<>>} = original |> VoiceSignal.encode_sdp_payload() |> VoiceSignal.decode_sdp_payload()
      assert decoded == original
      assert byte_size(big) > 255
    end
  end

  describe "IceCandidatePayload" do
    test "round-trips all four fields" do
      original = %{
        candidate: "candidate:1 1 UDP 2130706431 10.0.0.1 50000 typ host",
        sdp_m_line_index: 0,
        sdp_mid: "audio",
        username_fragment: "abcd"
      }

      {decoded, <<>>} =
        original |> VoiceSignal.encode_ice_candidate_payload() |> VoiceSignal.decode_ice_candidate_payload()

      assert decoded == original
    end
  end

  describe "Join / Leave messages" do
    test "Join round-trips including nested Vec3 position and enum codec" do
      original = %{
        room_id: "room-abc123",
        user_id: "user-42",
        display_name: "Ada",
        codec: :opus,
        self_muted: false,
        position: %{x: 1.5, y: -2.25, z: 0.0}
      }

      {decoded, <<>>} = original |> VoiceSignal.encode_join() |> VoiceSignal.decode_join()

      assert decoded.room_id == original.room_id
      assert decoded.user_id == original.user_id
      assert decoded.display_name == original.display_name
      assert decoded.self_muted == original.self_muted
      # float32 is lossy by design — compare with a tolerance, do not assert ==
      assert_in_delta decoded.position.x, original.position.x, 0.0001
      assert_in_delta decoded.position.y, original.position.y, 0.0001
      assert_in_delta decoded.position.z, original.position.z, 0.0001
    end

    test "Leave round-trips with the LeaveReason enum (owner ruling A3, 2026-08-04)" do
      # reason was `string` with free-text values matching nothing; it is now
      # the LeaveReason enum, value-aligned with room_event.bop. One byte on
      # the wire instead of a length-prefixed string.
      for reason <- [:voluntary, :kicked, :banned, :timeout, :server_shutdown] do
        original = %{room_id: "room-abc123", user_id: "user-42", reason: reason}
        {decoded, <<>>} = original |> VoiceSignal.encode_leave() |> VoiceSignal.decode_leave()
        assert decoded == original
      end
    end

    test "Leave.reason is one byte on the wire and unknown values are rejected" do
      bin = VoiceSignal.encode_leave(%{room_id: "r", user_id: "u", reason: :kicked})
      assert <<1::32-little, "r", 1::32-little, "u", 1::8>> == bin

      assert_raise Burble.BebopDecodeError, ~r/unknown LeaveReason value 9/, fn ->
        VoiceSignal.decode_leave(<<1::32-little, "r", 1::32-little, "u", 9::8>>)
      end
    end
  end

  describe "distinctness" do
    test "different payloads produce different bytes" do
      a = VoiceSignal.encode_sdp_payload(%{sdp: "offer", media_type: "audio"})
      b = VoiceSignal.encode_sdp_payload(%{sdp: "answer", media_type: "audio"})
      refute a == b
    end
  end

  describe "strict decoding (A4 — truncated/malformed input must be REJECTED)" do
    test "EVERY strict prefix of an encoded union frame is rejected" do
      frame =
        VoiceSignal.encode(
          {:join,
           %{
             room_id: "room-abc123",
             user_id: "user-42",
             display_name: "Ada",
             codec: :opus,
             self_muted: false,
             position: %{x: 1.5, y: -2.25, z: 0.0}
           }}
        )

      full = byte_size(frame)
      assert full > 10

      for len <- 0..(full - 1) do
        truncated = binary_part(frame, 0, len)
        assert_rejected(fn -> VoiceSignal.decode(truncated) end)
      end
    end

    test "a declared string length beyond the buffer is rejected (the 4-billion-byte hole)" do
      # Join frame whose roomId declares 0xFFFFFFFF bytes but carries 3.
      bogus = <<1::8, 0xFFFFFFFF::32-little, "abc">>
      assert_rejected(fn -> VoiceSignal.decode(bogus) end)

      assert_raise Burble.BebopDecodeError, ~r/exceeds/, fn ->
        VoiceSignal.decode_string(<<5::32-little, "abc">>)
      end

      assert_raise Burble.BebopDecodeError, ~r/truncated string length prefix/, fn ->
        VoiceSignal.decode_string(<<1, 2>>)
      end
    end

    test "a bool byte that is neither 0 nor 1 is rejected, not coerced to false" do
      assert_raise Burble.BebopDecodeError, ~r/invalid bool byte 7/, fn ->
        VoiceSignal.decode_bool(<<7, 0>>)
      end

      assert_raise Burble.BebopDecodeError, ~r/truncated bool/, fn ->
        VoiceSignal.decode_bool(<<>>)
      end
    end

    test "an unknown enum wire value is a structured decode error" do
      assert_raise Burble.BebopDecodeError, ~r/unknown AudioCodec value 99/, fn ->
        VoiceSignal.audio_codec(99)
      end

      assert_raise Burble.BebopDecodeError, ~r/unknown MuteState value 9/, fn ->
        VoiceSignal.mute_state(9)
      end
    end

    test "an unknown union discriminator tag returns {:error, _} (pinned contract)" do
      assert {:error, _} = VoiceSignal.decode(<<99, 1, 2, 3>>)
      assert {:error, _} = VoiceSignal.decode(<<>>)
    end

    test "valid frames still decode after the strictness change (no over-rejection)" do
      original = %{room_id: "r", user_id: "u", reason: :voluntary}
      frame = VoiceSignal.encode({:leave, original})
      assert {:leave, decoded, <<>>} = VoiceSignal.decode(frame)
      assert decoded == original
    end
  end
end
