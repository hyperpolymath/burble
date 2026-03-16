# SPDX-License-Identifier: PMPL-1.0-or-later
# Seeds for development — creates a test user.

alias Grumble.Auth

case Auth.register_user(%{
  email: "dev@grumble.local",
  display_name: "Dev User",
  password: "grumble_dev_123"
}) do
  {:ok, _user} -> IO.puts("Created dev user: dev@grumble.local / grumble_dev_123")
  {:error, _} -> IO.puts("Dev user already exists")
end
