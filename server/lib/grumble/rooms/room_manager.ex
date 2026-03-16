# SPDX-License-Identifier: PMPL-1.0-or-later
#
# Grumble.Rooms.RoomManager — Creates and finds room processes.
#
# Thin layer over DynamicSupervisor + Registry for room lifecycle.
# Room processes are started on demand and cleaned up via idle timeout.

defmodule Grumble.Rooms.RoomManager do
  @moduledoc """
  Manages room process lifecycle.

  Rooms are created on demand (first join) and automatically terminated
  after an idle timeout with no participants.
  """

  alias Grumble.Rooms.Room

  @doc "Find or create a room process. Returns {:ok, pid} or {:error, reason}."
  def ensure_room(room_id, opts \\ []) do
    case Registry.lookup(Grumble.RoomRegistry, room_id) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        start_room(room_id, opts)
    end
  end

  @doc "Start a new room process under the RoomSupervisor."
  def start_room(room_id, opts \\ []) do
    child_opts =
      Keyword.merge(opts, id: room_id)
      |> Keyword.put_new(:server_id, "default")
      |> Keyword.put_new(:name, "Room #{room_id}")

    DynamicSupervisor.start_child(
      Grumble.RoomSupervisor,
      {Room, child_opts}
    )
  end

  @doc "List all active room IDs."
  def list_active_rooms do
    Registry.select(Grumble.RoomRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  @doc "Count active rooms."
  def active_room_count do
    length(list_active_rooms())
  end

  @doc "Join a room (creating it if needed)."
  def join(room_id, user_id, user_info, room_opts \\ []) do
    case ensure_room(room_id, room_opts) do
      {:ok, _pid} -> Room.join(room_id, user_id, user_info)
      {:error, reason} -> {:error, reason}
    end
  end
end
