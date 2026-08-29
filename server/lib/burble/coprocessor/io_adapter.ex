# SPDX-License-Identifier: MPL-2.0
defmodule Burble.Coprocessor.IOAdapter do
  @moduledoc """
  Contract for a separately isolated host-I/O service adapter.

  SNIF guests are deliberately limited to pure numeric/buffer computation.
  Firewall mutation and PTP device access therefore belong behind an
  authenticated, least-privilege process boundary. An implementation of this
  behaviour may speak to that service; it must not load native code into the
  BEAM. Configure it as `config :burble, :isolated_io_adapter, ModuleName`.
  """

  @callback firewall_init() :: :ok | {:error, term()}
  @callback firewall_authorize(:inet.ip_address(), :inet.port_number()) ::
              :ok | {:error, term()}
  @callback firewall_revoke(:inet.ip_address()) :: :ok | {:error, term()}
  @callback ptp_read_clock() :: {:ok, integer()} | {:error, term()}
end
