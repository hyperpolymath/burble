# SPDX-License-Identifier: PMPL-1.0-or-later
#
# Burble.Permissions — Role-based permission system.
#
# Designed to be powerful but understandable:
#   - Role templates for common setups (Admin, Moderator, Member, Guest)
#   - Clear inheritance model (role -> channel overrides)
#   - Readable effective-permissions evaluation
#   - No ACL terror — if a permission question can't be answered
#     by reading the role + channel override, the system is wrong.

defmodule Burble.Permissions do
  @moduledoc """
  Permission evaluation for Burble servers.

  ## Permission model

  Permissions are bit flags on roles. A user's effective permissions
  in a channel are: `(role_permissions | channel_allow) & ~channel_deny`

  ## Built-in permissions

  Voice:
  - `:join_room` — enter a voice room
  - `:speak` — unmute and transmit audio
  - `:priority_speaker` — speak over others (attenuation)
  - `:whisper` — direct audio to specific users
  - `:mute_others` — server-mute other users
  - `:deafen_others` — server-deafen other users
  - `:move_others` — move users between rooms

  Text:
  - `:text` — send text messages
  - `:pin_messages` — pin messages in channels
  - `:manage_messages` — delete others' messages

  Admin:
  - `:manage_rooms` — create/edit/delete rooms
  - `:manage_roles` — create/edit roles (up to own level)
  - `:manage_server` — server-wide settings
  - `:manage_invites` — create/revoke invite links
  - `:kick` — kick users from server
  - `:ban` — ban users from server
  - `:view_audit_log` — access audit log
  """

  @all_permissions [
    :join_room,
    :speak,
    :priority_speaker,
    :whisper,
    :mute_others,
    :deafen_others,
    :move_others,
    :text,
    :pin_messages,
    :manage_messages,
    :manage_rooms,
    :manage_roles,
    :manage_server,
    :manage_invites,
    :kick,
    :ban,
    :view_audit_log
  ]

  @doc "All defined permissions."
  def all_permissions, do: @all_permissions

  @doc "Default role templates."
  def role_template(:admin) do
    MapSet.new(@all_permissions)
  end

  def role_template(:moderator) do
    MapSet.new([
      :join_room,
      :speak,
      :priority_speaker,
      :whisper,
      :mute_others,
      :deafen_others,
      :move_others,
      :text,
      :pin_messages,
      :manage_messages,
      :kick,
      :view_audit_log
    ])
  end

  def role_template(:member) do
    MapSet.new([:join_room, :speak, :whisper, :text])
  end

  def role_template(:guest) do
    MapSet.new([:join_room, :speak, :text])
  end

  @doc """
  Evaluate effective permissions for a user in a channel.

  Takes the user's role permissions and applies channel-specific
  allow/deny overrides.
  """
  def effective_permissions(role_perms, channel_allow \\ MapSet.new(), channel_deny \\ MapSet.new()) do
    role_perms
    |> MapSet.union(channel_allow)
    |> MapSet.difference(channel_deny)
  end

  @doc "Check if a permission set includes a specific permission."
  def has_permission?(perms, permission) do
    MapSet.member?(perms, permission)
  end

  @doc "Check if a user can perform an action in a channel."
  def can?(role_perms, permission, channel_allow \\ MapSet.new(), channel_deny \\ MapSet.new()) do
    effective_permissions(role_perms, channel_allow, channel_deny)
    |> has_permission?(permission)
  end
end
