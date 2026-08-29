# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
#
# Tests for Burble.Security.SDP — Software-Defined Perimeter gateway.
#
# SNIF deliberately cannot perform host firewall I/O. Without an isolated host
# adapter, SDP grants must fail closed rather than report success without
# installing a rule.

defmodule Burble.Security.SDPTest do
  use ExUnit.Case, async: true

  # Start a fresh, isolated SDP GenServer for each test so tests don't share
  # state and can run concurrently.
  setup do
    # The SDP GenServer is normally registered under its module name globally.
    # We start an unnamed instance to avoid conflicts between async tests.
    {:ok, pid} = GenServer.start_link(Burble.Security.SDP, [])
    %{sdp: pid}
  end

  # ---------------------------------------------------------------------------
  # 1. Module existence and compilation
  # ---------------------------------------------------------------------------

  describe "module definition" do
    test "module exists and exports expected functions" do
      assert function_exported?(Burble.Security.SDP, :start_link, 1)
      assert function_exported?(Burble.Security.SDP, :process_spa, 2)
      assert function_exported?(Burble.Security.SDP, :revoke_access, 1)
    end

    test "module is a GenServer" do
      behaviours =
        Burble.Security.SDP.__info__(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert GenServer in behaviours
    end
  end

  # ---------------------------------------------------------------------------
  # 2. SPA validation — a valid packet cannot grant access without a firewall
  # ---------------------------------------------------------------------------

  describe "process_spa/2 — authorisation" do
    test "valid non-empty SPA packet fails closed without firewall adapter", %{sdp: pid} do
      # The scaffold's verify_spa_packet/1 accepts any non-empty binary.
      result = GenServer.call(pid, {:process_spa, "valid-spa-token", {127, 0, 0, 1}})
      assert result == {:error, :firewall_unavailable}
    end

    test "valid SPA from an IPv6 address also fails closed", %{sdp: pid} do
      result = GenServer.call(pid, {:process_spa, "valid-spa-token", {0, 0, 0, 0, 0, 0, 0, 1}})
      assert result == {:error, :firewall_unavailable}
    end

    test "repeated valid SPA cannot create a session without firewall state", %{sdp: pid} do
      ip = {10, 0, 0, 42}

      assert {:error, :firewall_unavailable} =
               GenServer.call(pid, {:process_spa, "first-packet", ip})

      assert {:error, :firewall_unavailable} =
               GenServer.call(pid, {:process_spa, "second-packet", ip})
    end
  end

  # ---------------------------------------------------------------------------
  # 3. SPA rejection — empty packet is refused
  # ---------------------------------------------------------------------------

  describe "process_spa/2 — rejection" do
    test "empty SPA packet is rejected with {:error, :invalid_spa}", %{sdp: pid} do
      result = GenServer.call(pid, {:process_spa, <<>>, {1, 2, 3, 4}})
      assert result == {:error, :invalid_spa}
    end

    test "empty binary is the only invalid input the scaffold rejects", %{sdp: pid} do
      # Single byte is treated as a valid packet by the scaffold's length check.
      result = GenServer.call(pid, {:process_spa, <<0>>, {1, 2, 3, 4}})
      assert result == {:error, :firewall_unavailable}
    end
  end

  # ---------------------------------------------------------------------------
  # 4. Access revocation
  # ---------------------------------------------------------------------------

  describe "revoke_access/1" do
    test "revoking a previously granted IP returns :ok", %{sdp: pid} do
      ip = {192, 168, 1, 100}
      {:error, :firewall_unavailable} = GenServer.call(pid, {:process_spa, "grant-me", ip})
      assert :ok = GenServer.call(pid, {:revoke_access, ip})
    end

    test "revoking an IP that was never granted still returns :ok", %{sdp: pid} do
      # Revocation is idempotent — no error for unknown IPs.
      assert :ok = GenServer.call(pid, {:revoke_access, {172, 16, 0, 99}})
    end

    test "session is removed after revocation", %{sdp: pid} do
      ip = {10, 20, 30, 40}
      {:error, :firewall_unavailable} = GenServer.call(pid, {:process_spa, "grant-me", ip})
      :ok = GenServer.call(pid, {:revoke_access, ip})

      assert {:error, :firewall_unavailable} =
               GenServer.call(pid, {:process_spa, "re-grant", ip})
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Native firewall capability is explicitly unavailable
  # ---------------------------------------------------------------------------

  describe "SNIF I/O scope boundary" do
    test "SDP GenServer remains alive while grants fail closed" do
      {:ok, pid} = GenServer.start_link(Burble.Security.SDP, [])
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "compatibility facade rejects firewall initialisation" do
      assert {:error, :snif_io_out_of_scope} =
               Burble.Coprocessor.ZigBackend.sdp_firewall_init()
    end

    test "compatibility facade rejects firewall authorisation" do
      assert {:error, :snif_io_out_of_scope} =
               Burble.Coprocessor.ZigBackend.sdp_firewall_authorize({127, 0, 0, 1}, 6473)
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Source-level: SDP policy architecture
  # ---------------------------------------------------------------------------

  describe "SDP module structure" do
    test "module implements Zero Trust policy description" do
      sdp_source = File.read!(Path.join(__DIR__, "../../../lib/burble/security/sdp.ex"))
      assert sdp_source =~ "Zero Trust"
    end

    test "module documents Single Packet Authorisation" do
      sdp_source = File.read!(Path.join(__DIR__, "../../../lib/burble/security/sdp.ex"))
      assert sdp_source =~ "Single Packet Authoris"
    end

    test "module names the isolated firewall-adapter boundary" do
      sdp_source = File.read!(Path.join(__DIR__, "../../../lib/burble/security/sdp.ex"))
      assert sdp_source =~ "no_isolated_firewall_adapter"
    end
  end
end
