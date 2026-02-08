/// Package manager detection module.
///
/// This module provides functionality to detect the appropriate package manager
/// for the current project by scanning for lock files in the working directory.
/// The detection follows a priority-based approach where lower numbers indicate
/// higher priority (checked first).
const std = @import("std");
const ManagerType = @import("../types.zig").ManagerType;

/// Detects the current package manager type by checking for lock files.
///
/// This function scans the current working directory for known package manager
/// lock files in priority order. The first found determines file the package manager.
///
/// Detection Priority (lower number = higher priority):
///   0 - Cargo.toml (Rust/Cargo)
///   1 - pnpm-lock.yaml (pnpm)
///   2 - bun.lock (Bun)
///   3 - package-lock.json (npm)
///   4 - yarn.lock (Yarn)
///   5 - requirements.txt (pip - indicates Python project)
///   6 - pyproject.toml (Poetry)
///   7 - pdm.lock (PDM)
///
/// Returns:
///   ManagerType if a supported package manager is detected, null otherwise
///
/// Example:
///   ```zig
///   const manager = detectPackageManager();
///   if (manager) |m| {
///       std.debug.print("Detected: {s}\n", .{@tagName(m)});
///   } else {
///       std.debug.print("No supported package manager found\n", .{});
///   }
/// ```
pub fn detectPackageManager() ?ManagerType {
    const configs = [_]struct { priority: u8, file: []const u8 }{
        .{ .priority = 0, .file = "Cargo.toml" },
        .{ .priority = 1, .file = "pnpm-lock.yaml" },
        .{ .priority = 2, .file = "bun.lock" },
        .{ .priority = 3, .file = "package-lock.json" },
        .{ .priority = 4, .file = "yarn.lock" },
        .{ .priority = 5, .file = "requirements.txt" },
        .{ .priority = 6, .file = "pyproject.toml" },
        .{ .priority = 7, .file = "pdm.lock" },
    };

    for (configs, 0..) |config, i| {
        const file = std.fs.cwd().openFile(config.file, .{}) catch continue;
        defer file.close();
        return @as(ManagerType, @enumFromInt(i));
    }

    return null;
}
