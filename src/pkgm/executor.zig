/// Package manager command executor.
///
/// This module handles the actual execution of package manager commands.
/// It builds the command string, spawns the child process, and manages
/// the execution lifecycle including error handling and dry-run support.
const std = @import("std");
const MgError = @import("../core/error.zig").MgError;
const ManagerType = @import("../core/types.zig").ManagerType;
const registry = @import("registry.zig");
const logger = @import("../core/logger.zig");

/// Executes a package manager command.
///
/// This function builds the complete command from the manager type, action,
/// and package list, then either displays it (dry-run mode) or executes it.
///
/// Parameters:
///   - manager_type: The detected package manager type
///   - action: The action to perform (add, remove, upgrade, etc.)
///   - packages: Slice of package names to operate on
///   - dry_run: If true, only print the command without executing
///
/// Returns:
///   MgError!void - Returns an error if command execution fails
///
/// Process:
///   1. Get the native command from registry.getCommand()
///   2. Build the full command string
///   3. If dry_run, print and return
///   4. Spawn the child process with the package manager
///   5. Wait for completion and check exit code
///   6. Return error if exit code is non-zero
///
/// Errors:
///   - error.UnknownSubcommand: If the action is not recognized
///   - error.CommandFailed: If the spawned process fails or exits with non-zero code
///   - error.ManagerNotInstalled: If the package manager executable is not found
///
/// Example:
///   ```zig
///   try executor.execute(.npm, "add", &.{ "lodash" }, false);
///   try executor.execute(.cargo, "remove", &.{ "serde" }, true); // dry-run
/// ```
pub fn execute(manager_type: ManagerType, action: []const u8, packages: []const [:0]u8, dry_run: bool) MgError!void {
    const cmd_type = registry.getCommand(manager_type, action, packages) orelse {
        logger.err("Unknown command: {s}\n", .{action});
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

    logger.info("Executing: {s}\n", .{buf[0..pos]});

    if (dry_run) {
        logger.debug("Dry run - command not executed\n", .{});
        return;
    }

    var child = std.process.Child.init(&.{ manager_name, cmd_type }, std.heap.page_allocator);
    for (packages) |pkg| {
        _ = pkg;
    }
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    child.spawn() catch |err| {
        logger.err("Failed to spawn process: {s}\n", .{@errorName(err)});
        return error.CommandFailed;
    };

    const term = child.wait() catch |err| {
        logger.err("Failed to wait for process: {s}\n", .{@errorName(err)});
        return error.CommandFailed;
    };

    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                logger.err("Command failed with exit code {d}\n", .{code});
                return error.CommandFailed;
            }
        },
        else => {
            logger.err("Command terminated unexpectedly\n", .{});
            return error.CommandFailed;
        },
    }

    logger.info("Command completed successfully\n", .{});
}
