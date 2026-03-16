# SPDX-License-Identifier: PMPL-1.0-or-later
#
# Grumble.Presence — Phoenix Presence tracker for voice rooms.
#
# Tracks who is in which room and their current voice state.
# Built on Phoenix.Presence which uses CRDTs for distributed state.

defmodule Grumble.Presence do
  @moduledoc """
  Presence tracker for Grumble voice rooms.

  Tracks users across rooms with voice state metadata.
  Automatically handles join/leave via WebSocket lifecycle.
  """

  use Phoenix.Presence,
    otp_app: :grumble,
    pubsub_server: Grumble.PubSub
end
