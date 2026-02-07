const std = @import("std");
const MgError = @import("../error.zig").MgError;
const ManagerType = @import("../types.zig").ManagerType;
const registry = @import("registry.zig");

pub fn execute(manager_type: ManagerType, action: []const u8, packages: []const [:0]u8, dry_run: bool) MgError!void {
    const cmd_type = registry.getCommand(manager_type, action, packages) orelse {
        std.debug.print("Unknown command: {s}\n", .{action});
        return error.UnknownSubcommand;
    };

    const manager_name = registry.getManagerName(manager_type);

    var buf: [4096]u8 = undefined;
    var pos: usize = 0;

    const prefix = std.fmt.bufPrint(&buf, "{s} {s}", .{ manager_name, cmd_type }) catch "";
    pos = prefix.len;
    for (packages) |pkg| {
        const remaining = buf.len - pos;
        if (remaining > 0) {
            const result = std.fmt.bufPrint(buf[pos..remaining], " {s}", .{pkg}) catch "";
            pos += result.len;
        }
    }

    std.debug.print("Executing: {s}\n", .{buf[0..pos]});

    if (dry_run) {
        std.debug.print("Dry run - command not executed\n", .{});
        return;
    }

    var child = std.process.Child.init(&.{ manager_name, cmd_type }, std.heap.page_allocator);
    for (packages) |pkg| {
        _ = pkg;
    }
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    child.spawn() catch |err| {
        std.debug.print("Failed to spawn process: {s}\n", .{@errorName(err)});
        return error.CommandFailed;
    };

    const term = child.wait() catch |err| {
        std.debug.print("Failed to wait for process: {s}\n", .{@errorName(err)});
        return error.CommandFailed;
    };

    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                std.debug.print("Command failed with exit code {d}\n", .{code});
                return error.CommandFailed;
            }
        },
        else => {
            std.debug.print("Command terminated unexpectedly\n", .{});
            return error.CommandFailed;
        },
    }

    std.debug.print("Command completed successfully\n", .{});
}
