# SPDX-License-Identifier: PMPL-1.0-or-later
#
# Burble.Auth — Authentication and session management.
#
# Supports multiple auth flows:
#   - Email magic link (primary, low-friction)
#   - Guest join (anonymous, limited permissions)
#   - One-time invite tokens
#   - MFA for admins (TOTP)
#
# Sessions are JWT-based via Guardian, with refresh token rotation.

defmodule Burble.Auth do
  @moduledoc """
  Authentication context for Burble.

  Handles user registration, login, guest access, and session management.
  """

  alias Burble.Repo
  alias Burble.Auth.User

  @doc "Register a new user account."
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc "Authenticate by email and password."
  def authenticate_by_email(email, password) do
    case Repo.get_by(User, email: String.downcase(email)) do
      nil ->
        # Constant-time comparison to prevent timing attacks
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}

      user ->
        if Bcrypt.verify_pass(password, user.password_hash) do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end
    end
  end

  @doc "Create a guest session (anonymous, limited permissions)."
  def create_guest_session(display_name) do
    guest_id = "guest_" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)

    {:ok,
     %{
       id: guest_id,
       display_name: display_name || "Guest",
       is_guest: true,
       permissions: [:join_room, :speak, :text]
     }}
  end

  @doc "Generate a magic link token for passwordless login."
  def generate_magic_link(email) do
    token = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    # Store token with expiry (15 minutes)
    # TODO: implement token storage in database
    {:ok, token}
  end

  @doc "Generate a one-time invite token for a server."
  def generate_invite_token(server_id, opts \\ []) do
    max_uses = Keyword.get(opts, :max_uses, 1)
    expires_in = Keyword.get(opts, :expires_in, 86_400)
    token = Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)

    {:ok,
     %{
       token: token,
       server_id: server_id,
       max_uses: max_uses,
       expires_at: DateTime.add(DateTime.utc_now(), expires_in, :second),
       uses: 0
     }}
  end
end
