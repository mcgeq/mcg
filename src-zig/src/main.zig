const std = @import("std");

pub const MgError = error{
    NoPackageManager,
    CommandFailed,
    InvalidArgument,
    MissingSubcommand,
    UnknownSubcommand,
};

pub fn getManagerName(manager_type: u8) []const u8 {
    return switch (manager_type) {
        0 => "cargo",
        1 => "npm",
        2 => "pnpm",
        3 => "bun",
        4 => "yarn",
        5 => "pip",
        6 => "poetry",
        7 => "pdm",
        else => "unknown",
    };
}

pub fn detectPackageManager() u8 {
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
        return @as(u8, @intCast(i));
    }

    return 255;
}

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.heap.page_allocator.free(args);

    if (args.len < 2) {
        std.debug.print("mg - Multi-package manager CLI\n", .{});
        std.debug.print("Usage: mg [options] <command> [args]\n", .{});
        std.debug.print("Commands: add, remove, upgrade, install, analyze\n", .{});
        std.debug.print("Options: --dry-run, --help\n", .{});
        return;
    }

    var dry_run = false;
    var i: usize = 1;

    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.startsWith(u8, arg, "--")) {
            const opt = arg[2..];
            if (std.mem.eql(u8, opt, "dry-run") or std.mem.eql(u8, opt, "d")) {
                dry_run = true;
            } else if (std.mem.eql(u8, opt, "help") or std.mem.eql(u8, opt, "h")) {
                std.debug.print("mg - Multi-package manager CLI\n", .{});
                return;
            } else {
                std.debug.print("Unknown option: {s}\n", .{arg});
            }
        } else break;
    }

    if (i >= args.len) {
        std.debug.print("Missing command\n", .{});
        return error.MissingSubcommand;
    }

    const cmd = args[i];
    i += 1;

    const manager_type = detectPackageManager();
    if (manager_type == 255) {
        std.debug.print("No supported package manager detected\n", .{});
        return error.NoPackageManager;
    }

    const manager_name = getManagerName(manager_type);
    std.debug.print("Using {s} package manager\n", .{manager_name});

    const packages = args[i..];

    var cmd_type: []const u8 = "";
    switch (cmd[0]) {
        'a', 'A' => {
            if (packages.len == 0) {
                std.debug.print("No packages specified\n", .{});
                return error.InvalidArgument;
            }
            cmd_type = switch (manager_type) {
                0 => "add",
                1, 2, 3, 4 => "install",
                5 => "install",
                6, 7 => "add",
                else => "add",
            };
        },
        'r', 'R' => {
            if (packages.len == 0) {
                std.debug.print("No packages specified\n", .{});
                return error.InvalidArgument;
            }
            cmd_type = switch (manager_type) {
                0 => "remove",
                1 => "uninstall",
                2, 3, 4 => "remove",
                5 => "uninstall",
                6, 7 => "remove",
                else => "remove",
            };
        },
        'u', 'U' => cmd_type = "update",
        'i', 'I' => cmd_type = switch (manager_type) {
            0 => "check",
            else => "install",
        },
        'l', 'L' => cmd_type = switch (manager_type) {
            0 => "tree",
            1, 2, 3, 4 => "list",
            5 => "list",
            6, 7 => "list",
            else => "list",
        },
        else => {
            std.debug.print("Unknown command: {s}\n", .{cmd});
            return error.UnknownSubcommand;
        },
    }

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

    var full_args = std.ArrayList([]const u8).initCapacity(std.heap.page_allocator, 32) catch unreachable;
    try full_args.append(std.heap.page_allocator, manager_name);
    try full_args.append(std.heap.page_allocator, cmd_type);
    for (packages) |pkg| {
        try full_args.append(std.heap.page_allocator, pkg);
    }

    std.debug.print("Executing: {s}\n", .{buf[0..pos]});

    if (dry_run) {
        std.debug.print("Dry run - command not executed\n", .{});
    } else {
        var child = std.process.Child.init(full_args.items, std.heap.page_allocator);
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;

        try child.spawn();
        const term = try child.wait();

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
    }

    std.debug.print("Command completed successfully\n", .{});
}
