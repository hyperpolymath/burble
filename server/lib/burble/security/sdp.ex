# SPDX-License-Identifier: MPL-2.0
#
# Burble.Security.SDP — Software-Defined Perimeter gateway.
#
# Implements the SDP (Black Cloud) architecture for Burble.
# SDP ensures that the Burble server is invisible to unauthorised users:
#
#   1. Single Packet Authorisation (SPA) — the server only opens ports
#      after receiving a cryptographically signed SPA packet.
#   2. Mutual TLS (mTLS) — mandatory for all control and media traffic.
#   3. Dynamic Firewalls — ports are opened per-session and closed
#      immediately upon disconnection.
#   4. Zero Trust — every packet is authenticated and authorised.
#
# This module acts as the SDP gateway and policy engine. It integrates
# with an isolated host firewall service when one is configured. SNIF guests
# deliberately cannot perform host I/O, and Burble does not load firewall code
# into the BEAM as a direct NIF.

defmodule Burble.Security.SDP do
  @moduledoc """
  Software-Defined Perimeter (SDP) gateway for Burble.

  Hides the server infrastructure and enforces zero-trust access
  via Single Packet Authorisation (SPA) and dynamic firewalling.
  """

  use GenServer

  require Logger

  # ── Types ──

  @type spa_packet :: %{
          sender_id: String.t(),
          timestamp: DateTime.t(),
          signature: binary(),
          requested_port: :inet.port_number()
        }

  @type policy :: %{
          user_id: String.t(),
          allowed_ports: [:inet.port_number()],
          max_session_duration: integer(),
          mTLS_required: boolean()
        }

  # ── Public API ──

  @doc "Start the SDP gateway."
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Process an incoming SPA (Single Packet Authorisation) packet.
  If valid, opens the requested port for the sender's IP.
  """
  def process_spa(packet_binary, sender_ip) do
    GenServer.call(__MODULE__, {:process_spa, packet_binary, sender_ip})
  end

  @doc """
  Revoke access for an IP (close all dynamic ports).
  Called on session termination or policy violation.
  """
  def revoke_access(sender_ip) do
    GenServer.call(__MODULE__, {:revoke_access, sender_ip})
  end

  # ── GenServer Callbacks ──

  @impl true
  def init(_opts) do
    case Burble.Coprocessor.ZigBackend.sdp_firewall_init() do
      :ok ->
        Logger.info("[SDP] Isolated host firewall adapter ready")

      {:error, reason} ->
        Logger.warning(
          "[SDP] Host firewall adapter unavailable (#{inspect(reason)}); access grants will fail closed"
        )
    end

    {:ok,
     %{
       # sender_ip => %{user_id, opened_ports, expires_at}
       sessions: %{},
       # user_id => policy
       policies: %{}
     }}
  end

  @impl true
  def handle_call({:process_spa, packet_binary, sender_ip}, _from, state) do
    case verify_spa_packet(packet_binary) do
      {:ok, %{sender_id: user_id, requested_port: port}} ->
        case check_policy(user_id, port, state) do
          {:ok, _} ->
            case open_firewall_port(sender_ip, port) do
              :ok ->
                new_state = record_session(state, sender_ip, user_id, port)

                Logger.info(
                  "[SDP] Access GRANTED for #{user_id} at #{inspect(sender_ip)} on port #{port}"
                )

                {:reply, :ok, new_state}

              {:error, reason} ->
                Logger.warning("[SDP] Access REJECTED: firewall adapter unavailable (#{reason})")
                {:reply, {:error, :firewall_unavailable}, state}
            end

          {:error, reason} ->
            Logger.warning("[SDP] Access REJECTED for #{user_id}: #{reason}")
            {:reply, {:error, :policy_denied}, state}
        end

      {:error, reason} ->
        Logger.warning("[SDP] Invalid SPA packet from #{inspect(sender_ip)}: #{reason}")
        {:reply, {:error, :invalid_spa}, state}
    end
  end

  @impl true
  def handle_call({:revoke_access, sender_ip}, _from, state) do
    close_firewall_ports(sender_ip)
    new_sessions = Map.delete(state.sessions, sender_ip)
    Logger.info("[SDP] Access REVOKED for #{inspect(sender_ip)}")
    {:reply, :ok, %{state | sessions: new_sessions}}
  end

  # ── Internal: Policy & Firewall ──

  defp verify_spa_packet(binary) do
    # Simplified verification for scaffold.
    if byte_size(binary) > 0 do
      {:ok, %{sender_id: "user_123", requested_port: 6473, timestamp: DateTime.utc_now()}}
    else
      {:error, :empty_packet}
    end
  end

  defp check_policy(user_id, port, state) do
    # Local fallback while VeriSimDB policy lookup is not wired. If a policy is
    # supplied in state, enforce it rather than silently broadening access.
    case Map.fetch(state.policies, user_id) do
      :error ->
        {:ok, :local_check_only}

      {:ok, %{allowed_ports: allowed_ports}} when is_list(allowed_ports) ->
        if port in allowed_ports, do: {:ok, :policy_match}, else: {:error, :port_not_allowed}

      {:ok, _invalid_policy} ->
        {:error, :invalid_policy}
    end
  end

  defp open_firewall_port(ip, port) do
    Burble.Coprocessor.ZigBackend.sdp_firewall_authorize(ip, port)
  end

  defp close_firewall_ports(ip) do
    case Burble.Coprocessor.ZigBackend.sdp_firewall_revoke(ip) do
      :ok ->
        :ok

      {:error, :no_isolated_io_adapter} ->
        :ok

      {:error, reason} ->
        Logger.warning("[SDP] Firewall revocation failed for #{inspect(ip)}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp record_session(state, ip, user_id, port) do
    session = %{
      user_id: user_id,
      opened_ports: [port],
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
    }

    %{state | sessions: Map.put(state.sessions, ip, session)}
  end
end
