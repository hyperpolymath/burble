# SPDX-License-Identifier: PMPL-1.0-or-later

defmodule Grumble.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :display_name, :string, null: false, size: 32
      add :password_hash, :string, null: false
      add :is_admin, :boolean, default: false, null: false
      add :mfa_enabled, :boolean, default: false, null: false
      add :mfa_secret, :string
      add :last_seen_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])

    execute "CREATE EXTENSION IF NOT EXISTS citext", ""
  end
end
