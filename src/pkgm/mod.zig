const std = @import("std");
const MgError = @import("../error.zig").MgError;
const ManagerType = @import("../types.zig").ManagerType;

pub const detect = @import("detect.zig");
pub const registry = @import("registry.zig");
pub const executor = @import("executor.zig");

pub fn executeCommand(action: []const u8, packages: []const [:0]u8, dry_run: bool) MgError!void {
    const manager_type = detect.detectPackageManager() orelse {
        std.debug.print("No supported package manager detected\n", .{});
        return error.NoPackageManager;
    };

    const manager_name = registry.getManagerName(manager_type);
    std.debug.print("Using {s} package manager\n", .{manager_name});

    try executor.execute(manager_type, action, packages, dry_run);
}
