# SPDX-License-Identifier: MPL-2.0

defmodule Burble.LLM.TransportSecurityTest do
  use ExUnit.Case, async: true

  alias Burble.LLM.Transport

  test "TCP fallback is a real TLS listener and requires an authenticated client certificate" do
    opts = Transport.ssl_options()

    assert opts[:verify] == :verify_peer
    assert opts[:fail_if_no_peer_cert]
    assert is_binary(opts[:cacertfile])
    assert opts[:versions] == [:"tlsv1.3"]
    refute Keyword.has_key?(opts, :server_name_indication)
    refute Keyword.has_key?(opts, :ssl_opts)
  end

  test "listener fails closed when its certificate material is absent" do
    assert {:error, {:missing_tls_file, path}} = Transport.start_tcp_listener(0)
    refute File.regular?(path)
  end
end
