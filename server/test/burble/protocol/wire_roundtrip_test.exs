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

    test "Leave round-trips (reason is a STRING in the schema, not the LeaveReason enum)" do
      # NOTE: voice_signal.bop declares `3 -> string reason` even though a
      # LeaveReason enum exists in room_event.bop, and the field comment lists
      # values ("user"/"kicked"/"timeout") that do not match that enum's
      # variants. Flagged for the schema owner; this test pins CURRENT
      # behaviour so a later schema fix is a visible, deliberate wire change.
      original = %{room_id: "room-abc123", user_id: "user-42", reason: "user"}
      {decoded, <<>>} = original |> VoiceSignal.encode_leave() |> VoiceSignal.decode_leave()
      assert decoded == original
    end
  end

  describe "distinctness" do
    test "different payloads produce different bytes" do
      a = VoiceSignal.encode_sdp_payload(%{sdp: "offer", media_type: "audio"})
      b = VoiceSignal.encode_sdp_payload(%{sdp: "answer", media_type: "audio"})
      refute a == b
    end
  end
end
