# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Generated from: priv/schemas/room_event.bop
# Generator: mix bebop.generate
# DO NOT EDIT — regenerate with `mix bebop.generate`
#
# Bebop wire format: little-endian, length-prefixed strings (uint32 + UTF-8),
# 1-byte union discriminator tag.

defmodule Burble.Protocol.RoomEvent do
  @moduledoc """
  Bebop encoder/decoder for room_event.

  Auto-generated from `priv/schemas/room_event.bop`. Provides `encode/1` and `decode/1`
  for the top-level union type(s), plus struct/message codec helpers.

  ## Wire format

  - **Strings**: uint32-LE length prefix followed by UTF-8 bytes
  - **Bool**: one byte, `0` or `1` — any other byte is malformed
  - **uint8/uint16/uint32**: little-endian; **float32**: IEEE 754 LE
  - **Union**: 1-byte discriminator tag, then the variant payload

  Decoders are STRICT: truncated or malformed input raises
  `Burble.BebopDecodeError`. A frame that declares more bytes than it
  carries is rejected — never silently decoded to empty values.

  ## RoomEvent tags

  Each RoomEvent message is prefixed with a 1-byte discriminator tag:

  | Tag | Variant           | Direction |
  |-----|-------------------|-----------|
  |   1 | ParticipantJoined | -         |
  |   2 | ParticipantLeft   | -         |
  |   3 | VoiceStateChanged | -         |
  |   4 | RoomConfigUpdated | -         |
  """

  # ---------------------------------------------------------------------------
  # Enum: RoomType
  # The type of room, which determines media topology and permissions.
  # ---------------------------------------------------------------------------

  @doc "RoomType enum — Voice (1), Stage (2), Broadcast (3), Spatial (4)."
  def room_type(:voice), do: 1
  def room_type(:stage), do: 2
  def room_type(:broadcast), do: 3
  def room_type(:spatial), do: 4
  def room_type(1), do: :voice
  def room_type(2), do: :stage
  def room_type(3), do: :broadcast
  def room_type(4), do: :spatial

  def room_type(other) when is_integer(other) do
    raise Burble.BebopDecodeError, "unknown RoomType value #{other}"
  end


  # ---------------------------------------------------------------------------
  # Enum: LeaveReason
  # Reason a participant left the room.
  # ---------------------------------------------------------------------------

  @doc "LeaveReason enum — Voluntary (0), Kicked (1), Banned (2), Timeout (3), ServerShutdown (4)."
  def leave_reason(:voluntary), do: 0
  def leave_reason(:kicked), do: 1
  def leave_reason(:banned), do: 2
  def leave_reason(:timeout), do: 3
  def leave_reason(:server_shutdown), do: 4
  def leave_reason(0), do: :voluntary
  def leave_reason(1), do: :kicked
  def leave_reason(2), do: :banned
  def leave_reason(3), do: :timeout
  def leave_reason(4), do: :server_shutdown

  def leave_reason(other) when is_integer(other) do
    raise Burble.BebopDecodeError, "unknown LeaveReason value #{other}"
  end


  # ---------------------------------------------------------------------------
  # Enum: ParticipantRole
  # Permission level for a participant in the room.
  # ---------------------------------------------------------------------------

  @doc "ParticipantRole enum — Listener (0), Speaker (1), Moderator (2), Owner (3)."
  def participant_role(:listener), do: 0
  def participant_role(:speaker), do: 1
  def participant_role(:moderator), do: 2
  def participant_role(:owner), do: 3
  def participant_role(0), do: :listener
  def participant_role(1), do: :speaker
  def participant_role(2), do: :moderator
  def participant_role(3), do: :owner

  def participant_role(other) when is_integer(other) do
    raise Burble.BebopDecodeError, "unknown ParticipantRole value #{other}"
  end


  # ---------------------------------------------------------------------------
  # Struct: VoiceState
  # Snapshot of a participant's current voice state, included in join events
  # ---------------------------------------------------------------------------

  @doc "Encode a VoiceState struct to Bebop binary."
  def encode_voice_state(%{muted: muted, deafened: deafened, speaking: speaking, streaming: streaming, mute_type: mute_type}) do
    encode_bool(muted) <>
      encode_bool(deafened) <>
      encode_bool(speaking) <>
      encode_bool(streaming) <>
      <<mute_type::8>>
  end

  @doc "Decode a VoiceState struct from Bebop binary. Returns {struct_map, rest}."
  def decode_voice_state(data) do
    {muted, rest1} = decode_bool(data)
    {deafened, rest2} = decode_bool(rest1)
    {speaking, rest3} = decode_bool(rest2)
    {streaming, rest4} = decode_bool(rest3)
    {mute_type, rest5} = decode_uint8(rest4)
    {%{muted: muted, deafened: deafened, speaking: speaking, streaming: streaming, mute_type: mute_type}, rest5}
  end


  # ---------------------------------------------------------------------------
  # Struct: Participant
  # A participant descriptor — included in join/leave events.
  # ---------------------------------------------------------------------------

  @doc "Encode a Participant struct to Bebop binary."
  def encode_participant(%{user_id: user_id, display_name: display_name, avatar_url: avatar_url, role: role, voice_state: voice_state}) do
    encode_string(user_id) <>
      encode_string(display_name) <>
      encode_string(avatar_url) <>
      <<participant_role(role)::8>> <>
      encode_voice_state(voice_state)
  end

  @doc "Decode a Participant struct from Bebop binary. Returns {struct_map, rest}."
  def decode_participant(data) do
    {user_id, rest1} = decode_string(data)
    {display_name, rest2} = decode_string(rest1)
    {avatar_url, rest3} = decode_string(rest2)
    {role_raw, rest4} = decode_uint8(rest3)
    role = participant_role(role_raw)
    {voice_state, rest5} = decode_voice_state(rest4)
    {%{user_id: user_id, display_name: display_name, avatar_url: avatar_url, role: role, voice_state: voice_state}, rest5}
  end


  # ---------------------------------------------------------------------------
  # Struct: RoomConfig
  # Room configuration — sent on join and when config changes.
  # ---------------------------------------------------------------------------

  @doc "Encode a RoomConfig struct to Bebop binary."
  def encode_room_config(%{room_id: room_id, name: name, room_type: room_type, max_participants: max_participants, bitrate: bitrate, e2ee_required: e2ee_required, recording_active: recording_active, spatial_audio: spatial_audio, region: region}) do
    encode_string(room_id) <>
      encode_string(name) <>
      <<room_type(room_type)::8>> <>
      <<max_participants::32-little>> <>
      <<bitrate::32-little>> <>
      encode_bool(e2ee_required) <>
      encode_bool(recording_active) <>
      encode_bool(spatial_audio) <>
      encode_string(region)
  end

  @doc "Decode a RoomConfig struct from Bebop binary. Returns {struct_map, rest}."
  def decode_room_config(data) do
    {room_id, rest1} = decode_string(data)
    {name, rest2} = decode_string(rest1)
    {room_type_raw, rest3} = decode_uint8(rest2)
    room_type = room_type(room_type_raw)
    {max_participants, rest4} = decode_uint32(rest3)
    {bitrate, rest5} = decode_uint32(rest4)
    {e2ee_required, rest6} = decode_bool(rest5)
    {recording_active, rest7} = decode_bool(rest6)
    {spatial_audio, rest8} = decode_bool(rest7)
    {region, rest9} = decode_string(rest8)
    {%{room_id: room_id, name: name, room_type: room_type, max_participants: max_participants, bitrate: bitrate, e2ee_required: e2ee_required, recording_active: recording_active, spatial_audio: spatial_audio, region: region}, rest9}
  end


  # ---------------------------------------------------------------------------
  # Message: ParticipantJoined
  # A new participant has joined the room.
  # ---------------------------------------------------------------------------

  @doc "Encode a ParticipantJoined message to Bebop binary (no discriminator tag)."
  def encode_participant_joined(%{room_id: room_id, participant: participant, timestamp: timestamp, participant_count: participant_count}) do
    encode_string(room_id) <>
      encode_participant(participant) <>
      encode_string(timestamp) <>
      <<participant_count::32-little>>
  end

  @doc "Decode a ParticipantJoined message from Bebop binary. Returns {msg_map, rest}."
  def decode_participant_joined(data) do
    {room_id, rest1} = decode_string(data)
    {participant, rest2} = decode_participant(rest1)
    {timestamp, rest3} = decode_string(rest2)
    {participant_count, rest4} = decode_uint32(rest3)
    {%{room_id: room_id, participant: participant, timestamp: timestamp, participant_count: participant_count}, rest4}
  end


  # ---------------------------------------------------------------------------
  # Message: ParticipantLeft
  # A participant has left the room.
  # ---------------------------------------------------------------------------

  @doc "Encode a ParticipantLeft message to Bebop binary (no discriminator tag)."
  def encode_participant_left(%{room_id: room_id, user_id: user_id, reason: reason, timestamp: timestamp, participant_count: participant_count}) do
    encode_string(room_id) <>
      encode_string(user_id) <>
      <<leave_reason(reason)::8>> <>
      encode_string(timestamp) <>
      <<participant_count::32-little>>
  end

  @doc "Decode a ParticipantLeft message from Bebop binary. Returns {msg_map, rest}."
  def decode_participant_left(data) do
    {room_id, rest1} = decode_string(data)
    {user_id, rest2} = decode_string(rest1)
    {reason_raw, rest3} = decode_uint8(rest2)
    reason = leave_reason(reason_raw)
    {timestamp, rest4} = decode_string(rest3)
    {participant_count, rest5} = decode_uint32(rest4)
    {%{room_id: room_id, user_id: user_id, reason: reason, timestamp: timestamp, participant_count: participant_count}, rest5}
  end


  # ---------------------------------------------------------------------------
  # Message: VoiceStateChanged
  # A participant's voice state has changed (mute, deafen, speaking, role).
  # ---------------------------------------------------------------------------

  @doc "Encode a VoiceStateChanged message to Bebop binary (no discriminator tag)."
  def encode_voice_state_changed(%{room_id: room_id, user_id: user_id, voice_state: voice_state, role: role, timestamp: timestamp}) do
    encode_string(room_id) <>
      encode_string(user_id) <>
      encode_voice_state(voice_state) <>
      <<participant_role(role)::8>> <>
      encode_string(timestamp)
  end

  @doc "Decode a VoiceStateChanged message from Bebop binary. Returns {msg_map, rest}."
  def decode_voice_state_changed(data) do
    {room_id, rest1} = decode_string(data)
    {user_id, rest2} = decode_string(rest1)
    {voice_state, rest3} = decode_voice_state(rest2)
    {role_raw, rest4} = decode_uint8(rest3)
    role = participant_role(role_raw)
    {timestamp, rest5} = decode_string(rest4)
    {%{room_id: room_id, user_id: user_id, voice_state: voice_state, role: role, timestamp: timestamp}, rest5}
  end


  # ---------------------------------------------------------------------------
  # Message: RoomConfigUpdated
  # The room configuration has been updated by a moderator or owner.
  # ---------------------------------------------------------------------------

  @doc "Encode a RoomConfigUpdated message to Bebop binary (no discriminator tag)."
  def encode_room_config_updated(%{room_id: room_id, config: config, changed_by: changed_by, timestamp: timestamp}) do
    encode_string(room_id) <>
      encode_room_config(config) <>
      encode_string(changed_by) <>
      encode_string(timestamp)
  end

  @doc "Decode a RoomConfigUpdated message from Bebop binary. Returns {msg_map, rest}."
  def decode_room_config_updated(data) do
    {room_id, rest1} = decode_string(data)
    {config, rest2} = decode_room_config(rest1)
    {changed_by, rest3} = decode_string(rest2)
    {timestamp, rest4} = decode_string(rest3)
    {%{room_id: room_id, config: config, changed_by: changed_by, timestamp: timestamp}, rest4}
  end


  # ---------------------------------------------------------------------------
  # Union: RoomEvent — top-level encode/decode on the discriminator tag
  # Top-level envelope for room lifecycle events. Exactly one variant is set
  # ---------------------------------------------------------------------------

  def encode({:participant_joined, msg}) do
    payload = encode_participant_joined(msg)
    <<1::8, payload::binary>>
  end

  def encode({:participant_left, msg}) do
    payload = encode_participant_left(msg)
    <<2::8, payload::binary>>
  end

  def encode({:voice_state_changed, msg}) do
    payload = encode_voice_state_changed(msg)
    <<3::8, payload::binary>>
  end

  def encode({:room_config_updated, msg}) do
    payload = encode_room_config_updated(msg)
    <<4::8, payload::binary>>
  end

  def encode({unknown_tag, _msg}) do
    raise ArgumentError, "Unknown RoomEvent variant: #{inspect(unknown_tag)}"
  end

  def decode(<<1::8, payload::binary>>) do
    {msg, rest} = decode_participant_joined(payload)
    {:participant_joined, msg, rest}
  end

  def decode(<<2::8, payload::binary>>) do
    {msg, rest} = decode_participant_left(payload)
    {:participant_left, msg, rest}
  end

  def decode(<<3::8, payload::binary>>) do
    {msg, rest} = decode_voice_state_changed(payload)
    {:voice_state_changed, msg, rest}
  end

  def decode(<<4::8, payload::binary>>) do
    {msg, rest} = decode_room_config_updated(payload)
    {:room_config_updated, msg, rest}
  end

  def decode(<<tag::8, _::binary>>) do
    {:error, "Unknown RoomEvent discriminator tag: #{tag}"}
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
