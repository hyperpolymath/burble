# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

defmodule Burble.LLM do
  @moduledoc """
  Core LLM processing service for Burble.
  """

  require Logger

  # The provider module to delegate queries to. Set via configure_provider/1.
  # When nil, all queries return {:error, :no_provider_configured}.
  @provider nil

  @doc """
  Set the LLM provider module at runtime.
  The module must implement process_query/2 and stream_query/3.
  """
  def configure_provider(module) do
    :persistent_term.put({__MODULE__, :provider}, module)
    :ok
  end

  @doc """
  Process a synchronous LLM query.
  """
  def process_query(user_id, prompt) do
    Logger.debug("[LLM] Processing query for #{user_id}: #{prompt}")
    provider = :persistent_term.get({__MODULE__, :provider}, @provider)

    if provider do
      provider.process_query(user_id, prompt)
    else
      Logger.warning("[LLM] process_query called but no provider is configured")
      {:error, :no_provider_configured}
    end
  end

  @doc """
  Stream an LLM query response.
  """
  def stream_query(user_id, prompt, _callback) do
    Logger.debug("[LLM] Streaming query for #{user_id}: #{prompt}")
    provider = :persistent_term.get({__MODULE__, :provider}, @provider)

    if provider do
      provider.stream_query(user_id, prompt, _callback)
    else
      Logger.warning("[LLM] stream_query called but no provider is configured")
      {:error, :no_provider_configured}
    end
  end
end

defmodule Burble.LLM.Registry do
  @moduledoc """
  Registry for LLM connections.
  """

  def register_connection(user_id, pid) do
    :persistent_term.put({__MODULE__, user_id}, pid)
    :ok
  end

  def lookup_connection(user_id) do
    case :persistent_term.get({__MODULE__, user_id}, nil) do
      nil -> {:error, :not_found}
      pid -> {:ok, pid}
    end
  end
end
