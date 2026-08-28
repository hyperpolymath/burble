# SPDX-License-Identifier: MPL-2.0

defmodule Burble.Media.LMDBFrameCodec do
  @moduledoc false

  @type frame :: {non_neg_integer(), non_neg_integer(), binary()}

  # LMDB files are persistent input and can be corrupted or replaced
  # independently of the running BEAM. :safe prevents encoded
  # funs/references/PIDs from being materialised, while the shape check keeps a
  # malformed term from entering the real-time playout path.
  @spec decode(binary()) :: {:ok, frame()} | :not_found
  def decode(value_bin) do
    case :erlang.binary_to_term(value_bin, [:safe]) do
      {seq, timestamp_us, payload} = frame
      when is_integer(seq) and seq >= 0 and is_integer(timestamp_us) and timestamp_us >= 0 and
             is_binary(payload) ->
        {:ok, frame}

      _other ->
        :not_found
    end
  rescue
    ArgumentError -> :not_found
  end
end
