const std = @import("std");
const MgError = @import("error.zig").MgError;
const runtime = @import("runtime.zig");

pub fn findConfigFile(filename: []const u8, allocator: std.mem.Allocator) MgError!?[]const u8 {
    const io = runtime.get().io;
    var current_dir = std.process.currentPathAlloc(io, allocator) catch return null;

    while (true) {
        const path = std.fs.path.join(allocator, &[_][]const u8{ current_dir, filename }) catch return null;

        std.Io.Dir.cwd().access(io, path, .{}) catch {
            allocator.free(path);
            const parent = std.fs.path.dirname(current_dir);
            if (parent == null) {
                allocator.free(current_dir);
                return null;
            }
            const parent_copy = allocator.dupeZ(u8, parent.?) catch return error.IoError;
            allocator.free(current_dir);
            current_dir = parent_copy;
            continue;
        };

        allocator.free(current_dir);
        return path;
    }
}

pub fn getConfigDir(allocator: std.mem.Allocator) MgError![]const u8 {
    const environ_map = runtime.get().environ_map;

    if (environ_map.get("XDG_CONFIG_HOME")) |path| {
        return std.fs.path.join(allocator, &[_][]const u8{ path, "mg" }) catch return error.IoError;
    }

    if (environ_map.get("HOME")) |home| {
        return std.fs.path.join(allocator, &[_][]const u8{ home, ".config", "mg" }) catch return error.IoError;
    }

    if (environ_map.get("APPDATA")) |appdata| {
        return std.fs.path.join(allocator, &[_][]const u8{ appdata, "mg" }) catch return error.IoError;
    }

    return error.IoError;
}

pub fn getCacheDir(allocator: std.mem.Allocator) MgError![]const u8 {
    const environ_map = runtime.get().environ_map;

    if (environ_map.get("XDG_CACHE_HOME")) |path| {
        return std.fs.path.join(allocator, &[_][]const u8{ path, "mg" }) catch return error.IoError;
    }

    if (environ_map.get("HOME")) |home| {
        return std.fs.path.join(allocator, &[_][]const u8{ home, ".cache", "mg" }) catch return error.IoError;
    }

    if (environ_map.get("LOCALAPPDATA")) |local| {
        return std.fs.path.join(allocator, &[_][]const u8{ local, "mg", "cache" }) catch return error.IoError;
    }

    return error.IoError;
}
