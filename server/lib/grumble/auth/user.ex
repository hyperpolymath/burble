# SPDX-License-Identifier: PMPL-1.0-or-later
#
# Burble.Auth.User — User account schema.

defmodule Burble.Auth.User do
  @moduledoc """
  User account for Burble.

  Users can be full accounts (email + password) or guest sessions.
  Full accounts persist across sessions and can own/admin servers.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :email, :string
    field :display_name, :string
    field :password_hash, :string
    field :password, :string, virtual: true, redact: true
    field :is_admin, :boolean, default: false
    field :mfa_enabled, :boolean, default: false
    field :mfa_secret, :string, redact: true
    field :last_seen_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for user registration."
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :display_name, :password])
    |> validate_required([:email, :display_name, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "must be a valid email")
    |> validate_length(:display_name, min: 1, max: 32)
    |> validate_length(:password, min: 8, max: 128)
    |> unique_constraint(:email)
    |> hash_password()
  end

  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil ->
        changeset

      password ->
        changeset
        |> put_change(:password_hash, Bcrypt.hash_pwd_salt(password))
        |> delete_change(:password)
    end
  end
end
