# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

defmodule Burble.LLM.Worker do
  @moduledoc """
  Worker for NimblePool in the LLM service.
  """

  @behaviour NimblePool

  @impl true
  def init_pool(state) do
    {:ok, state}
  end

  @impl true
  def init_worker(state) do
    # In reality, this might open a persistent connection to an LLM provider.
    {:ok, %{}, state}
  end

  @impl true
  def handle_checkout(args, _from, worker_state, pool_state) do
    {:ok, args, worker_state, pool_state}
  end

  @impl true
  def handle_checkin(_args, _from, worker_state, pool_state) do
    {:ok, worker_state, pool_state}
  end

  @impl true
  def terminate_worker(_reason, _worker_state, pool_state) do
    {:ok, pool_state}
  end
end
