const std = @import("std");
const MgError = @import("error.zig").MgError;

pub fn findConfigFile(filename: []const u8, allocator: std.mem.Allocator) MgError!?[]const u8 {
    var current_dir = std.process.getCurrentDir() catch return null;

    while (true) {
        const path = std.fs.path.join(allocator, &[_][]const u8{ current_dir, filename }) catch return null;
        defer allocator.free(path);

        if (std.fs.exists(path)) {
            allocator.free(current_dir);
            return path;
        }

        const parent = std.fs.path.dirname(current_dir);
        if (parent == null) {
            allocator.free(current_dir);
            return null;
        }
        allocator.free(current_dir);
        current_dir = parent;
    }
}

pub fn getConfigDir(allocator: std.mem.Allocator) MgError![]const u8 {
    if (std.os.getenv("XDG_CONFIG_HOME")) |path| {
        return std.fs.path.join(allocator, &[_][]const u8{ path, "mg" }) catch return error.IoError;
    }

    if (std.os.getenv("HOME")) |home| {
        return std.fs.path.join(allocator, &[_][]const u8{ home, ".config", "mg" }) catch return error.IoError;
    }

    if (std.os.getenv("APPDATA")) |appdata| {
        return std.fs.path.join(allocator, &[_][]const u8{ appdata, "mg" }) catch return error.IoError;
    }

    return error.IoError;
}

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
