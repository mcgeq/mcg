const std = @import("std");
const MgError = @import("error.zig").MgError;
const ManagerType = @import("types.zig").ManagerType;

pub fn getCacheDir(allocator: std.mem.Allocator) MgError![]const u8 {
    if (std.os.getenv("XDG_CACHE_HOME")) |path| {
        return std.fs.path.join(allocator, &[_][]const u8{ path, "mg" }) catch return error.IoError;
    }

    if (std.os.getenv("HOME")) |home| {
        return std.fs.path.join(allocator, &[_][]const u8{ home, ".cache", "mg" }) catch return error.IoError;
    }

    if (std.os.getenv("LOCALAPPDATA")) |local| {
        return std.fs.path.join(allocator, &[_][]const u8{ local, "mg", "cache" }) catch return error.IoError;
    }

    return error.IoError;
}
