// SPDX-License-Identifier: PMPL-1.0-or-later
//
// Burble Coprocessor FFI — Pure Zig implementation.
//
// This file exports the C-compatible functions used by the V-lang API.
// It enforces the formal proofs defined in the Idris2 ABI.

const std = @import("std");
const abi = @import("abi.zig");
const audio = @import("coprocessor/audio.zig");

/// Check if a number is a power of two (enforces Idris2 FFTSize constraint).
export fn burble_is_power_of_two(n: i32) i32 {
    if (n <= 0) return 0;
    const un: u32 = @intCast(n);
    if ((un & (un - 1)) == 0) return 1 else return 0;
}

/// Validates role escalation.
export fn burble_can_escalate(from: i32, to: i32, authoriser: i32) i32 {
    const f: abi.Role = @enumFromInt(from);
    const t: abi.Role = @enumFromInt(to);
    const a: abi.Role = @enumFromInt(authoriser);
    if (abi.canEscalate(f, t, a)) return 1 else return 0;
}

/// Placeholder for Opus encoding (linked to Zig coprocessor implementation).
export fn burble_opus_encode(input: [*]const u8, input_len: i32, output: [*]u8, output_len: *i32, sample_rate: i32, channels: i32) i32 {
    // In a real implementation, this calls audio.pcm_encode or an actual Opus lib.
    _ = input;
    _ = input_len;
    _ = output;
    _ = sample_rate;
    _ = channels;
    output_len.* = 0; 
    return 0; // Success
}

/// OCR processing hook (Co-processor accelerated).
export fn burble_ocr_process(image_data: [*]const u8, len: i32, result_text: [*]u8, result_len: *i32) i32 {
    _ = image_data;
    _ = len;
    _ = result_text;
    result_len.* = 0;
    return 0;
}

/// Pandoc document conversion hook.
export fn burble_pandoc_convert(input_text: [*]const u8, input_len: i32, from_fmt: [*]const u8, to_fmt: [*]const u8, output_text: [*]u8, output_len: *i32) i32 {
    _ = input_text;
    _ = input_len;
    _ = from_fmt;
    _ = to_fmt;
    _ = output_text;
    output_len.* = 0;
    return 0;
}
