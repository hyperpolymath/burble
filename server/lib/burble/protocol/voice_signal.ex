# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Generated from: priv/schemas/voice_signal.bop
# Generator: mix bebop.generate
# DO NOT EDIT — regenerate with `mix bebop.generate`
#
# Bebop wire format: little-endian, length-prefixed strings (uint32 + UTF-8),
# 1-byte union discriminator tag.

defmodule Burble.Protocol.VoiceSignal do
  @moduledoc """
  Bebop encoder/decoder for voice_signal.

  Auto-generated from `priv/schemas/voice_signal.bop`. Provides `encode/1` and `decode/1`
  for the top-level union type(s), plus struct/message codec helpers.

  ## Wire format

  - **Strings**: uint32-LE length prefix followed by UTF-8 bytes
  - **Bool**: one byte, `0` or `1` — any other byte is malformed
  - **uint8/uint16/uint32**: little-endian; **float32**: IEEE 754 LE
  - **Union**: 1-byte discriminator tag, then the variant payload

  Decoders are STRICT: truncated or malformed input raises
  `Burble.BebopDecodeError`. A frame that declares more bytes than it
  carries is rejected — never silently decoded to empty values.

  ## VoiceSignal tags

  Each VoiceSignal message is prefixed with a 1-byte discriminator tag:

  | Tag | Variant        | Direction        |
  |-----|----------------|------------------|
  |   1 | Join           | Client -> Server |
  |   2 | Leave          | Client -> Server |
  |   3 | Mute           | Client -> Server |
  |   4 | Unmute         | Client -> Server |
  |   5 | Deafen         | Client -> Server |
  |   6 | SpeakingStart  | Server -> Client |
  |   7 | SpeakingStop   | Server -> Client |
  |   8 | PositionUpdate | Bidirectional    |
  |   9 | Offer          | Client -> Server |
  |  10 | Answer         | Server -> Client |
  |  11 | IceCandidate   | Bidirectional    |
  """

  # ---------------------------------------------------------------------------
  # Enum: AudioCodec
  # Audio codec negotiated for the voice session.
  # ---------------------------------------------------------------------------

  @doc "AudioCodec enum — Opus (1), Lyra (2)."
  def audio_codec(:opus), do: 1
  def audio_codec(:lyra), do: 2
  def audio_codec(1), do: :opus
  def audio_codec(2), do: :lyra

  def audio_codec(other) when is_integer(other) do
    raise Burble.BebopDecodeError, "unknown AudioCodec value #{other}"
  end


  # ---------------------------------------------------------------------------
  # Enum: MuteState
  # Mute state of a participant's microphone.
  # ---------------------------------------------------------------------------

  @doc "MuteState enum — Unmuted (0), SelfMuted (1), ServerMuted (2)."
  def mute_state(:unmuted), do: 0
  def mute_state(:self_muted), do: 1
  def mute_state(:server_muted), do: 2
  def mute_state(0), do: :unmuted
  def mute_state(1), do: :self_muted
  def mute_state(2), do: :server_muted

  def mute_state(other) when is_integer(other) do
    raise Burble.BebopDecodeError, "unknown MuteState value #{other}"
  end


  # ---------------------------------------------------------------------------
  # Enum: DeafenState
  # Deafen state — whether the participant receives audio.
  # ---------------------------------------------------------------------------

  @doc "DeafenState enum — Undeafened (0), SelfDeafened (1), ServerDeafened (2)."
  def deafen_state(:undeafened), do: 0
  def deafen_state(:self_deafened), do: 1
  def deafen_state(:server_deafened), do: 2
  def deafen_state(0), do: :undeafened
  def deafen_state(1), do: :self_deafened
  def deafen_state(2), do: :server_deafened

  def deafen_state(other) when is_integer(other) do
    raise Burble.BebopDecodeError, "unknown DeafenState value #{other}"
  end


  # ---------------------------------------------------------------------------
  # Struct: Vec3
  # Spatial position for 3D positional audio (used by BurbleSpatial extension
  # ---------------------------------------------------------------------------

  @doc "Encode a Vec3 struct to Bebop binary."
  def encode_vec3(%{x: x, y: y, z: z}) do
    <<x::float-little-32>> <>
      <<y::float-little-32>> <>
      <<z::float-little-32>>
  end

  @doc "Decode a Vec3 struct from Bebop binary. Returns {struct_map, rest}."
  def decode_vec3(data) do
    {x, rest1} = decode_float32(data)
    {y, rest2} = decode_float32(rest1)
    {z, rest3} = decode_float32(rest2)
    {%{x: x, y: y, z: z}, rest3}
  end


  # ---------------------------------------------------------------------------
  # Struct: IceCandidatePayload
  # ICE candidate for WebRTC connectivity checks (RFC 8445).
  # ---------------------------------------------------------------------------

  @doc "Encode a IceCandidatePayload struct to Bebop binary."
  def encode_ice_candidate_payload(%{candidate: candidate, sdp_m_line_index: sdp_m_line_index, sdp_mid: sdp_mid, username_fragment: username_fragment}) do
    encode_string(candidate) <>
      <<sdp_m_line_index::16-little>> <>
      encode_string(sdp_mid) <>
      encode_string(username_fragment)
  end

  @doc "Decode a IceCandidatePayload struct from Bebop binary. Returns {struct_map, rest}."
  def decode_ice_candidate_payload(data) do
    {candidate, rest1} = decode_string(data)
    {sdp_m_line_index, rest2} = decode_uint16(rest1)
    {sdp_mid, rest3} = decode_string(rest2)
    {username_fragment, rest4} = decode_string(rest3)
    {%{candidate: candidate, sdp_m_line_index: sdp_m_line_index, sdp_mid: sdp_mid, username_fragment: username_fragment}, rest4}
  end


  # ---------------------------------------------------------------------------
  # Struct: SdpPayload
  # SDP offer or answer payload for WebRTC session negotiation.
  # ---------------------------------------------------------------------------

  @doc "Encode a SdpPayload struct to Bebop binary."
  def encode_sdp_payload(%{sdp: sdp, media_type: media_type}) do
    encode_string(sdp) <>
      encode_string(media_type)
  end

  @doc "Decode a SdpPayload struct from Bebop binary. Returns {struct_map, rest}."
  def decode_sdp_payload(data) do
    {sdp, rest1} = decode_string(data)
    {media_type, rest2} = decode_string(rest1)
    {%{sdp: sdp, media_type: media_type}, rest2}
  end


  # ---------------------------------------------------------------------------
  # Message: Join
  # Client → Server: request to join a voice channel.
  # ---------------------------------------------------------------------------

  @doc "Encode a Join message to Bebop binary (no discriminator tag)."
  def encode_join(%{room_id: room_id, user_id: user_id, display_name: display_name, codec: codec, self_muted: self_muted, position: position}) do
    encode_string(room_id) <>
      encode_string(user_id) <>
      encode_string(display_name) <>
      <<audio_codec(codec)::8>> <>
      encode_bool(self_muted) <>
      encode_vec3(position)
  end

  @doc "Decode a Join message from Bebop binary. Returns {msg_map, rest}."
  def decode_join(data) do
    {room_id, rest1} = decode_string(data)
    {user_id, rest2} = decode_string(rest1)
    {display_name, rest3} = decode_string(rest2)
    {codec_raw, rest4} = decode_uint8(rest3)
    codec = audio_codec(codec_raw)
    {self_muted, rest5} = decode_bool(rest4)
    {position, rest6} = decode_vec3(rest5)
    {%{room_id: room_id, user_id: user_id, display_name: display_name, codec: codec, self_muted: self_muted, position: position}, rest6}
  end


  # ---------------------------------------------------------------------------
  # Message: Leave
  # Client → Server: leave the current voice channel gracefully.
  # ---------------------------------------------------------------------------

  @doc "Encode a Leave message to Bebop binary (no discriminator tag)."
  def encode_leave(%{room_id: room_id, user_id: user_id, reason: reason}) do
    encode_string(room_id) <>
      encode_string(user_id) <>
      encode_string(reason)
  end

  @doc "Decode a Leave message from Bebop binary. Returns {msg_map, rest}."
  def decode_leave(data) do
    {room_id, rest1} = decode_string(data)
    {user_id, rest2} = decode_string(rest1)
    {reason, rest3} = decode_string(rest2)
    {%{room_id: room_id, user_id: user_id, reason: reason}, rest3}
  end


  # ---------------------------------------------------------------------------
  # Message: Mute
  # Client → Server: toggle microphone mute.
  # ---------------------------------------------------------------------------

  @doc "Encode a Mute message to Bebop binary (no discriminator tag)."
  def encode_mute(%{room_id: room_id, user_id: user_id, state: state}) do
    encode_string(room_id) <>
      encode_string(user_id) <>
      <<mute_state(state)::8>>
  end

  @doc "Decode a Mute message from Bebop binary. Returns {msg_map, rest}."
  def decode_mute(data) do
    {room_id, rest1} = decode_string(data)
    {user_id, rest2} = decode_string(rest1)
    {state_raw, rest3} = decode_uint8(rest2)
    state = mute_state(state_raw)
    {%{room_id: room_id, user_id: user_id, state: state}, rest3}
  end


  # ---------------------------------------------------------------------------
  # Message: Unmute
  # Client → Server: remove mute (convenience — equivalent to Mute with Unmuted).
  # ---------------------------------------------------------------------------

  @doc "Encode a Unmute message to Bebop binary (no discriminator tag)."
  def encode_unmute(%{room_id: room_id, user_id: user_id}) do
    encode_string(room_id) <>
      encode_string(user_id)
  end

  @doc "Decode a Unmute message from Bebop binary. Returns {msg_map, rest}."
  def decode_unmute(data) do
    {room_id, rest1} = decode_string(data)
    {user_id, rest2} = decode_string(rest1)
    {%{room_id: room_id, user_id: user_id}, rest2}
  end


  # ---------------------------------------------------------------------------
  # Message: Deafen
  # Client → Server: toggle deafen (stop receiving audio).
  # ---------------------------------------------------------------------------

  @doc "Encode a Deafen message to Bebop binary (no discriminator tag)."
  def encode_deafen(%{room_id: room_id, user_id: user_id, state: state}) do
    encode_string(room_id) <>
      encode_string(user_id) <>
      <<deafen_state(state)::8>>
  end

  @doc "Decode a Deafen message from Bebop binary. Returns {msg_map, rest}."
  def decode_deafen(data) do
    {room_id, rest1} = decode_string(data)
    {user_id, rest2} = decode_string(rest1)
    {state_raw, rest3} = decode_uint8(rest2)
    state = deafen_state(state_raw)
    {%{room_id: room_id, user_id: user_id, state: state}, rest3}
  end


  # ---------------------------------------------------------------------------
  # Message: SpeakingStart
  # Server → Client: a participant has started speaking.
  # ---------------------------------------------------------------------------

  @doc "Encode a SpeakingStart message to Bebop binary (no discriminator tag)."
  def encode_speaking_start(%{room_id: room_id, user_id: user_id, audio_level: audio_level}) do
    encode_string(room_id) <>
      encode_string(user_id) <>
      <<audio_level::float-little-32>>
  end

  @doc "Decode a SpeakingStart message from Bebop binary. Returns {msg_map, rest}."
  def decode_speaking_start(data) do
    {room_id, rest1} = decode_string(data)
    {user_id, rest2} = decode_string(rest1)
    {audio_level, rest3} = decode_float32(rest2)
    {%{room_id: room_id, user_id: user_id, audio_level: audio_level}, rest3}
  end


  # ---------------------------------------------------------------------------
  # Message: SpeakingStop
  # Server → Client: a participant has stopped speaking.
  # ---------------------------------------------------------------------------

  @doc "Encode a SpeakingStop message to Bebop binary (no discriminator tag)."
  def encode_speaking_stop(%{room_id: room_id, user_id: user_id}) do
    encode_string(room_id) <>
      encode_string(user_id)
  end

  @doc "Decode a SpeakingStop message from Bebop binary. Returns {msg_map, rest}."
  def decode_speaking_stop(data) do
    {room_id, rest1} = decode_string(data)
    {user_id, rest2} = decode_string(rest1)
    {%{room_id: room_id, user_id: user_id}, rest2}
  end


  # ---------------------------------------------------------------------------
  # Message: PositionUpdate
  # Bidirectional: update spatial position for 3D audio panning.
  # ---------------------------------------------------------------------------

  @doc "Encode a PositionUpdate message to Bebop binary (no discriminator tag)."
  def encode_position_update(%{room_id: room_id, user_id: user_id, position: position, orientation: orientation}) do
    encode_string(room_id) <>
      encode_string(user_id) <>
      encode_vec3(position) <>
      <<orientation::float-little-32>>
  end

  @doc "Decode a PositionUpdate message from Bebop binary. Returns {msg_map, rest}."
  def decode_position_update(data) do
    {room_id, rest1} = decode_string(data)
    {user_id, rest2} = decode_string(rest1)
    {position, rest3} = decode_vec3(rest2)
    {orientation, rest4} = decode_float32(rest3)
    {%{room_id: room_id, user_id: user_id, position: position, orientation: orientation}, rest4}
  end


  # ---------------------------------------------------------------------------
  # Message: Offer
  # Client → Server: WebRTC SDP offer to establish or renegotiate media.
  # ---------------------------------------------------------------------------

  @doc "Encode a Offer message to Bebop binary (no discriminator tag)."
  def encode_offer(%{room_id: room_id, user_id: user_id, sdp: sdp}) do
    encode_string(room_id) <>
      encode_string(user_id) <>
      encode_sdp_payload(sdp)
  end

  @doc "Decode a Offer message from Bebop binary. Returns {msg_map, rest}."
  def decode_offer(data) do
    {room_id, rest1} = decode_string(data)
    {user_id, rest2} = decode_string(rest1)
    {sdp, rest3} = decode_sdp_payload(rest2)
    {%{room_id: room_id, user_id: user_id, sdp: sdp}, rest3}
  end


  # ---------------------------------------------------------------------------
  # Message: Answer
  # Server → Client: WebRTC SDP answer completing the offer/answer exchange.
  # ---------------------------------------------------------------------------

  @doc "Encode a Answer message to Bebop binary (no discriminator tag)."
  def encode_answer(%{room_id: room_id, user_id: user_id, sdp: sdp}) do
    encode_string(room_id) <>
      encode_string(user_id) <>
      encode_sdp_payload(sdp)
  end

  @doc "Decode a Answer message from Bebop binary. Returns {msg_map, rest}."
  def decode_answer(data) do
    {room_id, rest1} = decode_string(data)
    {user_id, rest2} = decode_string(rest1)
    {sdp, rest3} = decode_sdp_payload(rest2)
    {%{room_id: room_id, user_id: user_id, sdp: sdp}, rest3}
  end


  # ---------------------------------------------------------------------------
  # Message: IceCandidate
  # Bidirectional: exchange ICE candidates for connectivity checks.
  # ---------------------------------------------------------------------------

  @doc "Encode a IceCandidate message to Bebop binary (no discriminator tag)."
  def encode_ice_candidate(%{room_id: room_id, user_id: user_id, candidate: candidate}) do
    encode_string(room_id) <>
      encode_string(user_id) <>
      encode_ice_candidate_payload(candidate)
  end

  @doc "Decode a IceCandidate message from Bebop binary. Returns {msg_map, rest}."
  def decode_ice_candidate(data) do
    {room_id, rest1} = decode_string(data)
    {user_id, rest2} = decode_string(rest1)
    {candidate, rest3} = decode_ice_candidate_payload(rest2)
    {%{room_id: room_id, user_id: user_id, candidate: candidate}, rest3}
  end


  # ---------------------------------------------------------------------------
  # Union: VoiceSignal — top-level encode/decode on the discriminator tag
  # Top-level envelope for voice signaling. Exactly one variant is set per
  # ---------------------------------------------------------------------------

  def encode({:join, msg}) do
    payload = encode_join(msg)
    <<1::8, payload::binary>>
  end

  def encode({:leave, msg}) do
    payload = encode_leave(msg)
    <<2::8, payload::binary>>
  end

  def encode({:mute, msg}) do
    payload = encode_mute(msg)
    <<3::8, payload::binary>>
  end

  def encode({:unmute, msg}) do
    payload = encode_unmute(msg)
    <<4::8, payload::binary>>
  end

  def encode({:deafen, msg}) do
    payload = encode_deafen(msg)
    <<5::8, payload::binary>>
  end

  def encode({:speaking_start, msg}) do
    payload = encode_speaking_start(msg)
    <<6::8, payload::binary>>
  end

  def encode({:speaking_stop, msg}) do
    payload = encode_speaking_stop(msg)
    <<7::8, payload::binary>>
  end

  def encode({:position_update, msg}) do
    payload = encode_position_update(msg)
    <<8::8, payload::binary>>
  end

  def encode({:offer, msg}) do
    payload = encode_offer(msg)
    <<9::8, payload::binary>>
  end

  def encode({:answer, msg}) do
    payload = encode_answer(msg)
    <<10::8, payload::binary>>
  end

  def encode({:ice_candidate, msg}) do
    payload = encode_ice_candidate(msg)
    <<11::8, payload::binary>>
  end

  def encode({unknown_tag, _msg}) do
    raise ArgumentError, "Unknown VoiceSignal variant: #{inspect(unknown_tag)}"
  end

  def decode(<<1::8, payload::binary>>) do
    {msg, rest} = decode_join(payload)
    {:join, msg, rest}
  end

  def decode(<<2::8, payload::binary>>) do
    {msg, rest} = decode_leave(payload)
    {:leave, msg, rest}
  end

  def decode(<<3::8, payload::binary>>) do
    {msg, rest} = decode_mute(payload)
    {:mute, msg, rest}
  end

  def decode(<<4::8, payload::binary>>) do
    {msg, rest} = decode_unmute(payload)
    {:unmute, msg, rest}
  end

  def decode(<<5::8, payload::binary>>) do
    {msg, rest} = decode_deafen(payload)
    {:deafen, msg, rest}
  end

  def decode(<<6::8, payload::binary>>) do
    {msg, rest} = decode_speaking_start(payload)
    {:speaking_start, msg, rest}
  end

  def decode(<<7::8, payload::binary>>) do
    {msg, rest} = decode_speaking_stop(payload)
    {:speaking_stop, msg, rest}
  end

  def decode(<<8::8, payload::binary>>) do
    {msg, rest} = decode_position_update(payload)
    {:position_update, msg, rest}
  end

  def decode(<<9::8, payload::binary>>) do
    {msg, rest} = decode_offer(payload)
    {:offer, msg, rest}
  end

  def decode(<<10::8, payload::binary>>) do
    {msg, rest} = decode_answer(payload)
    {:answer, msg, rest}
  end

  def decode(<<11::8, payload::binary>>) do
    {msg, rest} = decode_ice_candidate(payload)
    {:ice_candidate, msg, rest}
  end

  def decode(<<tag::8, _::binary>>) do
    {:error, "Unknown VoiceSignal discriminator tag: #{tag}"}
  end

  def decode(<<>>) do
    {:error, "Empty input — no discriminator tag"}
  end


  # ---------------------------------------------------------------------------
  # Primitive codecs (Bebop wire format) — strict: malformed input raises
  # Burble.BebopDecodeError instead of decoding to a default value.
  # ---------------------------------------------------------------------------

  @doc "Encode a Bebop string: uint32-LE length prefix followed by UTF-8 bytes."
  def encode_string(str) when is_binary(str) do
    len = byte_size(str)
    <<len::32-little, str::binary>>
  end

  @doc "Decode a Bebop string. Returns {string, rest}; raises on truncation."
  def decode_string(<<len::32-little, str::binary-size(len), rest::binary>>) do
    {str, rest}
  end

  def decode_string(<<len::32-little, rest::binary>>) do
    raise Burble.BebopDecodeError,
          "string length #{len} exceeds the #{byte_size(rest)} bytes remaining"
  end

  def decode_string(data) do
    raise Burble.BebopDecodeError,
          "truncated string length prefix: #{byte_size(data)} of 4 bytes"
  end

  @doc "Encode a boolean as a single byte (0 or 1)."
  def encode_bool(true), do: <<1::8>>
  def encode_bool(false), do: <<0::8>>

  @doc "Decode a boolean byte. Only 0 and 1 are valid; anything else raises."
  def decode_bool(<<1::8, rest::binary>>), do: {true, rest}
  def decode_bool(<<0::8, rest::binary>>), do: {false, rest}

  def decode_bool(<<other::8, _::binary>>) do
    raise Burble.BebopDecodeError, "invalid bool byte #{other} (want 0 or 1)"
  end

  def decode_bool(<<>>) do
    raise Burble.BebopDecodeError, "truncated bool: 0 of 1 bytes"
  end

  @doc "Decode a uint8. Returns {value, rest}; raises on truncation."
  def decode_uint8(<<v::8, rest::binary>>), do: {v, rest}

  def decode_uint8(data) do
    raise Burble.BebopDecodeError,
          "truncated uint8: #{byte_size(data)} of 1 bytes"
  end

  @doc "Decode a uint16 (little-endian). Returns {value, rest}; raises on truncation."
  def decode_uint16(<<v::16-little, rest::binary>>), do: {v, rest}

  def decode_uint16(data) do
    raise Burble.BebopDecodeError,
          "truncated uint16: #{byte_size(data)} of 2 bytes"
  end

  @doc "Decode a uint32 (little-endian). Returns {value, rest}; raises on truncation."
  def decode_uint32(<<v::32-little, rest::binary>>), do: {v, rest}

  def decode_uint32(data) do
    raise Burble.BebopDecodeError,
          "truncated uint32: #{byte_size(data)} of 4 bytes"
  end

  @doc "Decode a float32 (IEEE 754 LE). Returns {value, rest}; raises on truncation. NaN/Inf bit patterns do not match Elixir float segments and are rejected too."
  def decode_float32(<<v::float-little-32, rest::binary>>), do: {v, rest}

  def decode_float32(data) do
    raise Burble.BebopDecodeError,
          "truncated or non-finite float32 (#{byte_size(data)} bytes available)"
  end

end
