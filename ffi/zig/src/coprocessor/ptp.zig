// Burble Coprocessor — PTP hardware clock kernel.
//
// Reads the PTP hardware clock via /dev/ptp0 ioctl (PTP_CLOCK_GETTIME).
// On systems without a PTP hardware clock, returns an error so the
// Elixir caller can fall back to phc2sys/NTP/system clock.

const std = @import("std");

pub const PTP_CLOCK_GETTIME = 0xc0087001; // from linux/ptp_clock.h

pub const PtpTime = struct {
    seconds: i64,
    nanoseconds: u32,
};

/// Read the PTP hardware clock. Returns nanoseconds since epoch.
/// Returns error.NoPtpDevice if /dev/ptp0 doesn't exist.
/// Returns error.IoctlFailed if the ioctl call fails.
pub fn read_ptp_clock(device_path: []const u8) !i64 {
    const fd = std.posix.open(device_path, .{ .ACCMODE = .RDONLY }, 0) catch {
        return error.NoPtpDevice;
    };
    defer std.posix.close(fd);

    // For now, return a stub error indicating the ioctl is not yet wired.
    // The actual PTP_CLOCK_GETTIME ioctl requires:
    //   struct ptp_sys_offset { unsigned int n_samples; ... }
    // and is Linux-specific. This stub exists so the NIF registration
    // and Elixir wiring can be tested before the ioctl is implemented.
    return error.IoctlNotImplemented;
}

test "read_ptp_clock returns error on non-existent device" {
    const result = read_ptp_clock("/dev/nonexistent_ptp_device");
    try std.testing.expectError(error.NoPtpDevice, result);
}
