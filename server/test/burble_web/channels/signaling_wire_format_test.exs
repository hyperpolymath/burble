# SPDX-License-Identifier: MPL-2.0
#
# Wire-format tests for the signalling plane (spline ADR-0005 criterion (a)).
#
# These exercise the encode/decode helpers directly rather than standing up a
# full socket, so they assert the PLANE SELECTION and the round-trip contract
# without depending on channel auth/transport setup.

defmodule BurbleWeb.SignalingWireFormatTest do
  use ExUnit.Case, async: false

  alias BurbleWeb.SignalingChannel

  setup do
    original = Application.get_env(:burble, :signaling_wire_format, :json)
    on_exit(fn -> Application.put_env(:burble, :signaling_wire_format, original) end)
    :ok
  end

  describe "default plane (criterion (a) requires the DEFAULT path)" do
    test "the shipped default is :json" do
      # config/config.exs pins this. If someone flips the default, this test
      # fails and forces the change to be deliberate.
      Application.delete_env(:burble, :signaling_wire_format)
      assert SignalingChannel.wire_format() == :json
    end
  end

  describe "decode_sdp_body/1" do
    test "passes JSON-plane payloads through untouched" do
      payload = %{type: "sdp:offer", from: "u1", enc: "json", sdp: "v=0", mediaType: "audio"}
      assert SignalingChannel.decode_sdp_body(payload) == payload
    end

    test "decodes a Bebop-plane payload back to a plain sdp string" do
      bin = Burble.Protocol.VoiceSignal.encode_sdp_payload(%{sdp: "v=0\r\nfoo", media_type: "audio"})

      out =
        SignalingChannel.decode_sdp_body(%{
          type: "sdp:offer",
          from: "u1",
          enc: "bebop",
          sdp_b64: Base.encode64(bin),
          mediaType: "audio"
        })

      assert out.sdp == "v=0\r\nfoo"
      assert out.enc == "json", "decoded payloads are normalised for existing clients"
      refute Map.has_key?(out, :sdp_b64)
    end

    test "malformed Bebop payload is forwarded as-is, never raises" do
      bad = %{type: "sdp:offer", from: "u1", enc: "bebop", sdp_b64: "!!!not-base64!!!"}
      assert SignalingChannel.decode_sdp_body(bad) == bad
    end

    test "truncated Bebop binary is forwarded as-is, NOT silently decoded to an empty SDP" do
      # REGRESSION GUARD. The generated decoders do not detect truncation: this
      # buffer declares a uint32-LE string length of 4_294_967_295 with one byte
      # following, and decode_string returns "" rather than failing. Without the
      # round-trip integrity check in decode_sdp_body/1 a truncated frame would
      # arrive as a valid-looking EMPTY offer — worse than an obvious error.
      # Caught by CI on the first run of this suite (2026-07-28).
      bad = %{type: "sdp:offer", from: "u1", enc: "bebop", sdp_b64: Base.encode64(<<255, 255, 255, 255, 1>>)}
      assert SignalingChannel.decode_sdp_body(bad) == bad
    end

    test "trailing garbage after a valid payload is forwarded as-is" do
      good = Burble.Protocol.VoiceSignal.encode_sdp_payload(%{sdp: "v=0", media_type: "audio"})
      bad = %{type: "sdp:offer", from: "u1", enc: "bebop", sdp_b64: Base.encode64(good <> "XX")}
      assert SignalingChannel.decode_sdp_body(bad) == bad
    end

    test "a legitimately empty SDP still decodes (the guard is not over-eager)" do
      bin = Burble.Protocol.VoiceSignal.encode_sdp_payload(%{sdp: "", media_type: ""})
      out = SignalingChannel.decode_sdp_body(%{type: "sdp:offer", from: "u1", enc: "bebop", sdp_b64: Base.encode64(bin)})
      assert out.sdp == ""
      assert out.enc == "json"
    end
  end

  describe "end-to-end plane round-trip" do
    test "an SDP body survives encode-on-send + decode-on-receive via Bebop" do
      sdp = "v=0\r\no=- 0 0 IN IP4 127.0.0.1\r\nm=audio 9 UDP/TLS/RTP/SAVPF 111\r\n"
      bin = Burble.Protocol.VoiceSignal.encode_sdp_payload(%{sdp: sdp, media_type: "audio"})

      out =
        SignalingChannel.decode_sdp_body(%{
          type: "sdp:answer",
          from: "peer",
          enc: "bebop",
          sdp_b64: Base.encode64(bin),
          mediaType: "audio"
        })

      assert out.sdp == sdp
    end
  end
end
