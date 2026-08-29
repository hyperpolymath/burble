# SPDX-License-Identifier: MPL-2.0
#
# Compatibility facade retained for callers that selected the former direct
# Zig NIF backend. Estate policy forbids application-owned in-VM NIFs: pure
# numeric/buffer acceleration belongs in SNIF/WASM and safe fallback stays on
# the BEAM. The name remains temporarily to avoid an unrelated public API break.

defmodule Burble.Coprocessor.ZigBackend do
  @moduledoc """
  Compatibility facade for the retired direct Zig NIF backend.

  Burble no longer loads an application-owned shared library into the BEAM.
  SNIF-compatible kernels are routed by `Burble.Coprocessor.SNIFBackend`; until
  their ReleaseSafe WASM artifacts and buffer ABI are available, this facade
  delegates compute to the reference BEAM implementation. Native I/O operations
  that SNIF cannot model fail explicitly.
  """

  @behaviour Burble.Coprocessor.Backend

  alias Burble.Coprocessor.ElixirBackend

  @impl true
  def backend_type, do: :zig_retired

  @impl true
  def available?, do: false

  @impl true
  def audio_encode(pcm, sample_rate, channels, bitrate),
    do: ElixirBackend.audio_encode(pcm, sample_rate, channels, bitrate)

  @impl true
  def audio_decode(frame, sample_rate, channels),
    do: ElixirBackend.audio_decode(frame, sample_rate, channels)

  @impl true
  def audio_noise_gate(pcm, threshold_db),
    do: ElixirBackend.audio_noise_gate(pcm, threshold_db)

  @impl true
  def audio_echo_cancel(capture, reference, filter_length),
    do: ElixirBackend.audio_echo_cancel(capture, reference, filter_length)

  @impl true
  def opus_transcode(pcm_or_opus, sample_rate, channels, bitrate),
    do: ElixirBackend.opus_transcode(pcm_or_opus, sample_rate, channels, bitrate)

  @impl true
  def opus_available?, do: false

  @impl true
  def audio_agc(pcm, target_rms_db, attack_ms, release_ms, state),
    do: ElixirBackend.audio_agc(pcm, target_rms_db, attack_ms, release_ms, state)

  @impl true
  def audio_comfort_noise(frame_length, level_db, noise_profile),
    do: ElixirBackend.audio_comfort_noise(frame_length, level_db, noise_profile)

  @impl true
  def audio_spectral_vad(pcm, sample_rate, state),
    do: ElixirBackend.audio_spectral_vad(pcm, sample_rate, state)

  @impl true
  def audio_perceptual_weight(magnitudes, sample_rate),
    do: ElixirBackend.audio_perceptual_weight(magnitudes, sample_rate)

  @impl true
  def compress_audio_archive(frames, sample_rate, channels),
    do: ElixirBackend.compress_audio_archive(frames, sample_rate, channels)

  @impl true
  def decompress_audio_frame(archive, frame_index),
    do: ElixirBackend.decompress_audio_frame(archive, frame_index)

  @impl true
  def crypto_encrypt_frame(plaintext, key, aad),
    do: ElixirBackend.crypto_encrypt_frame(plaintext, key, aad)

  @impl true
  def crypto_decrypt_frame(ciphertext, key, iv, tag, aad),
    do: ElixirBackend.crypto_decrypt_frame(ciphertext, key, iv, tag, aad)

  @impl true
  def crypto_hash_chain(previous_hash, payload),
    do: ElixirBackend.crypto_hash_chain(previous_hash, payload)

  @impl true
  def crypto_derive_frame_key(shared_secret, salt, info),
    do: ElixirBackend.crypto_derive_frame_key(shared_secret, salt, info)

  @impl true
  def io_jitter_buffer_push(buffer_state, packet, sequence, timestamp),
    do: ElixirBackend.io_jitter_buffer_push(buffer_state, packet, sequence, timestamp)

  @impl true
  def io_conceal_loss(previous_frames, frame_size),
    do: ElixirBackend.io_conceal_loss(previous_frames, frame_size)

  @impl true
  def io_adaptive_bitrate(loss_ratio, rtt_ms, current_bitrate),
    do: ElixirBackend.io_adaptive_bitrate(loss_ratio, rtt_ms, current_bitrate)

  @impl true
  def dsp_fft(signal, size), do: ElixirBackend.dsp_fft(signal, size)

  @impl true
  def dsp_ifft(spectrum, size), do: ElixirBackend.dsp_ifft(spectrum, size)

  @impl true
  def dsp_convolve(a, b), do: ElixirBackend.dsp_convolve(a, b)

  @impl true
  def dsp_mix(streams, matrix), do: ElixirBackend.dsp_mix(streams, matrix)

  @impl true
  def neural_init_model(sample_rate), do: ElixirBackend.neural_init_model(sample_rate)

  @impl true
  def neural_denoise(pcm, sample_rate, model_state),
    do: ElixirBackend.neural_denoise(pcm, sample_rate, model_state)

  @impl true
  def neural_classify_noise(pcm, sample_rate),
    do: ElixirBackend.neural_classify_noise(pcm, sample_rate)

  @impl true
  def compress_lz4(data), do: ElixirBackend.compress_lz4(data)

  @impl true
  def decompress_lz4(compressed, original_size),
    do: ElixirBackend.decompress_lz4(compressed, original_size)

  @impl true
  def compress_zstd(data, level), do: ElixirBackend.compress_zstd(data, level)

  @impl true
  def decompress_zstd(compressed), do: ElixirBackend.decompress_zstd(compressed)

  @doc "Initialise firewall state through the configured isolated I/O adapter."
  def sdp_firewall_init, do: call_io_adapter(:firewall_init, [])

  @doc "Authorise an address through the configured isolated I/O adapter."
  def sdp_firewall_authorize(ip_tuple, port),
    do: call_io_adapter(:firewall_authorize, [ip_tuple, port])

  @doc "Revoke an address through the configured isolated I/O adapter."
  def sdp_firewall_revoke(ip_tuple), do: call_io_adapter(:firewall_revoke, [ip_tuple])

  @doc "Read PTP time through the configured isolated I/O adapter."
  def ptp_read_clock, do: call_io_adapter(:ptp_read_clock, [])

  defp call_io_adapter(function, arguments) do
    case Application.get_env(:burble, :isolated_io_adapter) do
      module when is_atom(module) and not is_nil(module) ->
        if Code.ensure_loaded?(module) and function_exported?(module, function, length(arguments)) do
          apply(module, function, arguments)
        else
          {:error, :invalid_isolated_io_adapter}
        end

      _ ->
        {:error, :no_isolated_io_adapter}
    end
  rescue
    exception -> {:error, {:isolated_io_adapter_exception, Exception.message(exception)}}
  catch
    kind, reason -> {:error, {:isolated_io_adapter_failure, kind, reason}}
  end
end
