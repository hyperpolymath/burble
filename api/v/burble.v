// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Burble V-lang API — Voice platform coprocessor client.
// Wraps the Zig FFI which implements the Idris2 ABI.
module burble

// ═══════════════════════════════════════════════════════════════════════
// Types (mirror Idris2 ABI: Burble.ABI.Types)
// ═══════════════════════════════════════════════════════════════════════

pub enum CoprocessorResult {
	ok
	@error
	invalid_param
	buffer_too_small
	not_initialised
	codec_error
	crypto_error
	out_of_memory
}

pub enum SampleRate {
	rate_8000  = 8000
	rate_16000 = 16000
	rate_48000 = 48000
}

pub struct AudioConfig {
pub:
	sample_rate SampleRate
	channels    int // 1 or 2 only (proven by ABI)
	buffer_size int // Must be power-of-2 (proven by ABI)
}

// ═══════════════════════════════════════════════════════════════════════
// Internationalisation (linked to standards/lol)
// ═══════════════════════════════════════════════════════════════════════

pub struct Language {
pub:
	iso3 string
	name string
}

// translate handles cross-language text alignment via the LOL corpus.
pub fn translate(text string, target_iso3 string) !string {
	// In production, this calls the LOL orchestrator.
	return text
}

// ═══════════════════════════════════════════════════════════════════════
// Live Chat Tools (Co-processor supported)
// ═══════════════════════════════════════════════════════════════════════

// process_ocr extracts text from an image using co-processor acceleration.
pub fn process_ocr(image_data []u8) !string {
	mut output := []u8{len: 4096}
	mut out_len := output.len
	result := C.burble_ocr_process(image_data.data, image_data.len, output.data, &out_len)
	if result != 0 {
		return error('OCR processing failed')
	}
	return output[..out_len].bytestring()
}

// convert_document uses Pandoc functionality for live chat transformations.
pub fn convert_document(text string, from_fmt string, to_fmt string) !string {
	mut output := []u8{len: text.len * 2}
	mut out_len := output.len
	result := C.burble_pandoc_convert(text.str, text.len, from_fmt.str, to_fmt.str, output.data,
		&out_len)
	if result != 0 {
		return error('Pandoc conversion failed')
	}
	return output[..out_len].bytestring()
}

// ═══════════════════════════════════════════════════════════════════════
// Security (File Isolation)
// ═══════════════════════════════════════════════════════════════════════

import os

// secure_file_send implements executable isolation with chmod lockdown.
pub fn secure_file_send(file_path string) ! {
	// Lockdown: remove all execute permissions before sending.
	// This prevents accidental execution of untrusted files.
	os.chmod(file_path, 0o644) or { return error('Failed to lockdown file: ${err.msg()}') }
}

// ═══════════════════════════════════════════════════════════════════════
// FFI bindings (calls into Zig coprocessor layer)
// ═══════════════════════════════════════════════════════════════════════

fn C.burble_opus_encode(input &u8, input_len int, output &u8, output_len &int, sample_rate int, channels int) int
fn C.burble_opus_decode(input &u8, input_len int, output &u8, output_len &int, sample_rate int, channels int) int
fn C.burble_ocr_process(image_data &u8, len int, result_text &u8, result_len &int) int
fn C.burble_pandoc_convert(input_text &char, input_len int, from_fmt &char, to_fmt &char, output_text &u8, output_len &int) int
fn C.burble_aes_encrypt(plaintext &u8, len int, key &u8, key_len int, output &u8) int
fn C.burble_aes_decrypt(ciphertext &u8, len int, key &u8, key_len int, output &u8) int
fn C.burble_is_power_of_two(n int) int

// ═══════════════════════════════════════════════════════════════════════
// Public API
// ═══════════════════════════════════════════════════════════════════════

// encode_opus encodes raw PCM audio to Opus format.
pub fn encode_opus(pcm []u8, config AudioConfig) ![]u8 {
	mut output := []u8{len: pcm.len}
	mut out_len := output.len
	result := C.burble_opus_encode(pcm.data, pcm.len, output.data, &out_len,
		int(config.sample_rate), config.channels)
	if result != 0 {
		return error('opus encode failed: ${result}')
	}
	return output[..out_len]
}

// decode_opus decodes Opus audio to raw PCM.
pub fn decode_opus(opus_data []u8, config AudioConfig) ![]u8 {
	mut output := []u8{len: opus_data.len * 10}
	mut out_len := output.len
	result := C.burble_opus_decode(opus_data.data, opus_data.len, output.data, &out_len,
		int(config.sample_rate), config.channels)
	if result != 0 {
		return error('opus decode failed: ${result}')
	}
	return output[..out_len]
}

// encrypt_aes256 encrypts data with AES-256.
pub fn encrypt_aes256(plaintext []u8, key []u8) ![]u8 {
	if key.len != 32 {
		return error('AES-256 key must be exactly 32 bytes')
	}
	mut output := []u8{len: plaintext.len + 16}
	result := C.burble_aes_encrypt(plaintext.data, plaintext.len, key.data, key.len, output.data)
	if result != 0 {
		return error('encryption failed: ${result}')
	}
	return output
}

// is_valid_buffer_size checks if a buffer size is power-of-2 (ABI requirement).
pub fn is_valid_buffer_size(size int) bool {
	return C.burble_is_power_of_two(size) == 1
}
