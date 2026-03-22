# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Migration 001: Initial VeriSimDB setup for Burble.
#
# Creates the namespace prefixes and seed octads that Burble expects.
# This script is idempotent -- safe to run multiple times.

defmodule Burble.Store.Migrations.InitialSetup do
  @moduledoc """
  Initial VeriSimDB namespace setup for Burble.

  Creates octad namespace prefixes:
  - `user:` — User accounts
  - `magic:` — Magic link tokens (ephemeral)
  - `invite:` — Invite tokens
  - `room_config:` — Room configuration
  - `server_config:` — Server/guild configuration
  - `_migration:` — Migration tracking

  Also creates the migration tracking octad itself.
  """

  @version 1
  @description "Initial VeriSimDB schema setup"

  def version, do: @version
  def description, do: @description

  @doc """
  Run the migration against the given VeriSimClient connection.

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  def up(client) do
    # VeriSimDB is schemaless — octads are created on demand. This migration
    # verifies connectivity and creates the migration tracking octad so that
    # future migrations can check which version has been applied.
    #
    # The namespace prefixes (user:, magic:, invite:, etc.) are conventions
    # enforced by Burble.Store, not VeriSimDB-level constructs.

    migration_octad = %{
      name: "_migration:burble",
      description: "Burble migration tracking — do not delete",
      metadata: %{entity_type: "burble_migration_tracker"},
      document: %{
        content: Jason.encode!(%{
          current_version: @version,
          applied_at: DateTime.to_iso8601(DateTime.utc_now()),
          migrations: [
            %{
              version: @version,
              description: @description,
              applied_at: DateTime.to_iso8601(DateTime.utc_now())
            }
          ]
        }),
        content_type: "application/json",
        metadata: %{schema_version: 1}
      }
    }

    case VeriSimClient.Octad.create(client, migration_octad) do
      {:ok, _octad} -> :ok
      # If it already exists, that is fine — idempotent.
      {:error, {:conflict, _}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
