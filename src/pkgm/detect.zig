const std = @import("std");
const ManagerType = @import("../types.zig").ManagerType;

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
