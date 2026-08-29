// SPDX-License-Identifier: MPL-2.0
//
// Burble coprocessor kernel tests. Application-owned Erlang NIF construction
// was removed: production acceleration must use ReleaseSafe WASM through SNIF.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const audio_mod = b.createModule(.{
        .root_source_file = b.path("src/coprocessor/audio.zig"),
        .target = target,
        .optimize = optimize,
    });
    const dsp_mod = b.createModule(.{
        .root_source_file = b.path("src/coprocessor/dsp.zig"),
        .target = target,
        .optimize = optimize,
    });
    const neural_mod = b.createModule(.{
        .root_source_file = b.path("src/coprocessor/neural.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "dsp", .module = dsp_mod }},
    });
    const firewall_mod = b.createModule(.{
        .root_source_file = b.path("src/coprocessor/firewall.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_mod = b.createModule(.{
        .root_source_file = b.path("test/coprocessor_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "audio", .module = audio_mod },
            .{ .name = "dsp", .module = dsp_mod },
            .{ .name = "neural", .module = neural_mod },
            .{ .name = "firewall", .module = firewall_mod },
        },
    });

    const tests = b.addTest(.{ .root_module = test_mod });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run coprocessor kernel unit tests");
    test_step.dependOn(&run_tests.step);
}
