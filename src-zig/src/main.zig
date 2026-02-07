const std = @import("std");

pub const MgError = error{
    NoPackageManager,
    CommandFailed,
    InvalidArgument,
    MissingSubcommand,
    UnknownSubcommand,
    PathOperationFailed,
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

pub fn fsCreate(path: []const u8, is_dir: bool, dry_run: bool) !void {
    if (dry_run) {
        std.debug.print("[dry-run] Create {s}: {s}\n", .{ if (is_dir) "directory" else "file", path });
        return;
    }

    if (is_dir) {
        std.fs.cwd().makePath(path) catch {
            std.debug.print("Error: Failed to create directory: {s}\n", .{path});
            return;
        };
        std.debug.print("Created directory: {s}\n", .{path});
    } else {
        const file = std.fs.cwd().createFile(path, .{}) catch {
            std.debug.print("Error: Failed to create file: {s}\n", .{path});
            return;
        };
        file.close();
        std.debug.print("Created file: {s}\n", .{path});
    }
}

pub fn fsRemove(path: []const u8, recursive: bool, dry_run: bool) !void {
    if (dry_run) {
        std.debug.print("[dry-run] Remove: {s}\n", .{path});
        return;
    }

    const exists = std.fs.cwd().openFile(path, .{}) catch |err| blk: {
        if (err == error.FileNotFound or err == error.PathNotFound) {
            std.debug.print("Error: Path not found: {s}\n", .{path});
            return;
        }
        break :blk null;
    };
    if (exists) |f| {
        f.close();
    }

    if (recursive) {
        std.fs.cwd().deleteTree(path) catch |err| {
            std.debug.print("Error: Failed to remove {s}: {s}\n", .{ path, @errorName(err) });
            return;
        };
    } else {
        std.fs.cwd().deleteFile(path) catch |err| {
            std.debug.print("Error: Failed to remove {s}: {s}\n", .{ path, @errorName(err) });
            return;
        };
    }
    std.debug.print("Removed: {s}\n", .{path});
}

pub fn fsCopy(src: []const u8, dst: []const u8, dry_run: bool) !void {
    if (dry_run) {
        std.debug.print("[dry-run] Copy: {s} -> {s}\n", .{ src, dst });
        return;
    }

    std.fs.cwd().copyFile(src, std.fs.cwd(), dst, .{}) catch {
        std.debug.print("Error: Source not found: {s}\n", .{src});
        return;
    };
    std.debug.print("Copied: {s} -> {s}\n", .{ src, dst });
}

pub fn fsCopyExtended(src: []const u8, dst: []const u8, recursive: bool, dry_run: bool) !void {
    if (dry_run) {
        std.debug.print("[dry-run] Copy {s}: {s} -> {s}\n", .{ if (recursive) "recursive" else "", src, dst });
        return;
    }

    const src_file = std.fs.cwd().openFile(src, .{}) catch null;
    if (src_file) |f| {
        f.close();
        std.fs.cwd().copyFile(src, std.fs.cwd(), dst, .{}) catch {
            std.debug.print("Error: Failed to copy to: {s}\n", .{dst});
            return;
        };
        std.debug.print("Copied: {s} -> {s}\n", .{ src, dst });
    } else {
        if (recursive) {
            copyDirAll(src, dst) catch {
                std.debug.print("Error: Source not found: {s}\n", .{src});
                return;
            };
            std.debug.print("Copied directory: {s} -> {s}\n", .{ src, dst });
        } else {
            std.debug.print("Error: {s} is a directory, use --recursive\n", .{src});
        }
    }
}

fn copyDirAll(src: []const u8, dst: []const u8) !void {
    var src_dir = std.fs.cwd().openDir(src, .{ .iterate = true }) catch return error.PathNotFound;
    defer src_dir.close();

    std.fs.cwd().makePath(dst) catch {};

    var iter = src_dir.iterate();
    while (iter.next() catch null) |entry| {
        const src_path = std.fs.path.join(std.heap.page_allocator, &.{ src, entry.name }) catch continue;
        defer std.heap.page_allocator.free(src_path);
        const dst_path = std.fs.path.join(std.heap.page_allocator, &.{ dst, entry.name }) catch continue;
        defer std.heap.page_allocator.free(dst_path);

        if (entry.kind == .directory) {
            copyDirAll(src_path, dst_path) catch {};
        } else if (entry.kind == .file) {
            std.fs.cwd().copyFile(src_path, std.fs.cwd(), dst_path, .{}) catch {};
        }
    }
}

pub fn fsCreateExtended(path: []const u8, is_dir: bool, recursive: bool, dry_run: bool) !void {
    if (dry_run) {
        std.debug.print("[dry-run] Create {s}: {s}\n", .{ if (is_dir) "directory" else "file", path });
        return;
    }

    if (is_dir) {
        std.fs.cwd().makePath(path) catch {
            std.debug.print("Error: Failed to create directory: {s}\n", .{path});
            return;
        };
        std.debug.print("Created directory: {s}\n", .{path});
    } else {
        const file = std.fs.cwd().createFile(path, .{}) catch |err| {
            if (err == error.FileNotFound and recursive) {
                const parent = std.fs.path.dirname(path);
                if (parent) |p| {
                    std.fs.cwd().makePath(p) catch {
                        std.debug.print("Error: Failed to create parent directory: {s}\n", .{p});
                        return;
                    };
                    const f = std.fs.cwd().createFile(path, .{}) catch {
                        std.debug.print("Error: Failed to create file: {s}\n", .{path});
                        return;
                    };
                    f.close();
                    std.debug.print("Created file: {s}\n", .{path});
                    return;
                }
            }
            std.debug.print("Error: Failed to create file: {s}\n", .{path});
            return;
        };
        file.close();
        std.debug.print("Created file: {s}\n", .{path});
    }
}

pub fn fsMove(src: []const u8, dst: []const u8, dry_run: bool) !void {
    if (dry_run) {
        std.debug.print("[dry-run] Move: {s} -> {s}\n", .{ src, dst });
        return;
    }

    std.fs.cwd().rename(src, dst) catch {
        std.debug.print("Error: Source not found: {s}\n", .{src});
        return;
    };
    std.debug.print("Moved: {s} -> {s}\n", .{ src, dst });
}

pub fn fsList(path: []const u8, dry_run: bool) !void {
    if (dry_run) {
        std.debug.print("[dry-run] List: {s}\n", .{path});
        return;
    }

    var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch {
        std.debug.print("Error: Path not found: {s}\n", .{path});
        return;
    };
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        const mark = if (entry.kind == .directory) "/" else "";
        std.debug.print("  {s}{s}\n", .{ entry.name, mark });
    }
}

pub fn fsExists(path: []const u8, dry_run: bool) !void {
    if (dry_run) {
        std.debug.print("[dry-run] Exists check: {s}\n", .{path});
        return;
    }

    const file = std.fs.cwd().openFile(path, .{}) catch null;
    if (file) |f| {
        f.close();
        std.debug.print("{s} exists\n", .{path});
    } else {
        std.debug.print("{s} not found\n", .{path});
    }
}

pub fn fsRead(path: []const u8, dry_run: bool) !void {
    if (dry_run) {
        std.debug.print("[dry-run] Read: {s}\n", .{path});
        return;
    }

    const file = std.fs.cwd().openFile(path, .{}) catch {
        std.debug.print("Error: File not found: {s}\n", .{path});
        return;
    };
    defer file.close();

    const content = file.readToEndAlloc(std.heap.page_allocator, std.math.maxInt(usize)) catch "";
    defer std.heap.page_allocator.free(content);
    std.debug.print("{s}", .{content});
}

pub fn fsWrite(path: []const u8, content: []const u8, dry_run: bool) !void {
    if (dry_run) {
        std.debug.print("[dry-run] Write {d} bytes to: {s}\n", .{ content.len, path });
        return;
    }

    const file = std.fs.cwd().createFile(path, .{}) catch {
        std.debug.print("Error: Failed to create file: {s}\n", .{path});
        return;
    };
    defer file.close();
    file.writeAll(content) catch {};
    std.debug.print("Wrote {d} bytes to: {s}\n", .{ content.len, path });
}

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.heap.page_allocator.free(args);

    if (args.len < 2) {
        std.debug.print("mg - Multi-package manager CLI\n", .{});
        std.debug.print("Usage: mg [options] <command> [args]\n", .{});
        std.debug.print("Commands: add, remove, upgrade, install, analyze\n", .{});
        std.debug.print("FS Commands: fs create, fs remove, fs copy, fs move, fs list, fs read, fs write\n", .{});
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

    if (std.mem.eql(u8, cmd, "fs") or std.mem.eql(u8, cmd, "f")) {
        if (i >= args.len) {
            std.debug.print("Usage: mg fs <subcommand> [args]\n", .{});
            std.debug.print("Subcommands: create(c,touch), remove(r), copy(y), move(m), list, read, write\n", .{});
            return;
        }
        const fs_cmd = args[i];
        i += 1;
        const path_args = args[i..];

        if (std.mem.eql(u8, fs_cmd, "create") or std.mem.eql(u8, fs_cmd, "c") or std.mem.eql(u8, fs_cmd, "touch")) {
            if (path_args.len < 1) {
                std.debug.print("Usage: mg fs create <path> [--dir] [--recursive|-r]\n", .{});
                return;
            }
            var is_dir = false;
            var recursive = true;
            var path_idx: usize = 0;
            for (path_args, 0..) |p, idx| {
                if (std.mem.eql(u8, p, "--dir")) {
                    is_dir = true;
                } else if (std.mem.eql(u8, p, "--recursive") or std.mem.eql(u8, p, "-r")) {
                    recursive = true;
                } else {
                    path_idx = idx;
                }
            }
            const paths = path_args[path_idx..];
            for (paths) |p| {
                if (std.mem.startsWith(u8, p, "--")) continue;
                try fsCreateExtended(p, is_dir, recursive, dry_run);
            }
        } else if (std.mem.eql(u8, fs_cmd, "remove") or std.mem.eql(u8, fs_cmd, "rm") or std.mem.eql(u8, fs_cmd, "r")) {
            if (path_args.len < 1) {
                std.debug.print("Usage: mg fs remove <path> [--recursive|-r]\n", .{});
                return;
            }
            var recursive = true;
            var path_idx: usize = 0;
            for (path_args, 0..) |p, idx| {
                if (std.mem.eql(u8, p, "--recursive") or std.mem.eql(u8, p, "-r")) {
                    recursive = true;
                } else {
                    path_idx = idx;
                }
            }
            const paths = path_args[path_idx..];
            for (paths) |p| {
                if (std.mem.startsWith(u8, p, "--")) continue;
                fsRemove(p, recursive, dry_run) catch {};
            }
        } else if (std.mem.eql(u8, fs_cmd, "copy") or std.mem.eql(u8, fs_cmd, "cp") or std.mem.eql(u8, fs_cmd, "y")) {
            if (path_args.len < 2) {
                std.debug.print("Usage: mg fs copy <src> <dst> [--recursive|-r]\n", .{});
                return;
            }
            var recursive = true;
            const src = path_args[0];
            const dst = path_args[1];
            for (path_args[2..]) |p| {
                if (std.mem.eql(u8, p, "--recursive") or std.mem.eql(u8, p, "-r")) {
                    recursive = true;
                }
            }
            try fsCopyExtended(src, dst, recursive, dry_run);
        } else if (std.mem.eql(u8, fs_cmd, "move") or std.mem.eql(u8, fs_cmd, "mv") or std.mem.eql(u8, fs_cmd, "m")) {
            if (path_args.len < 2) {
                std.debug.print("Usage: mg fs move <src> <dst>\n", .{});
                return;
            }
            try fsMove(path_args[0], path_args[1], dry_run);
        } else if (std.mem.eql(u8, fs_cmd, "list") or std.mem.eql(u8, fs_cmd, "ls")) {
            const path = if (path_args.len > 0) path_args[0] else ".";
            try fsList(path, dry_run);
        } else if (std.mem.eql(u8, fs_cmd, "exists") or std.mem.eql(u8, fs_cmd, "test")) {
            if (path_args.len < 1) {
                std.debug.print("Usage: mg fs exists <path>\n", .{});
                return;
            }
            try fsExists(path_args[0], dry_run);
        } else if (std.mem.eql(u8, fs_cmd, "read") or std.mem.eql(u8, fs_cmd, "cat")) {
            if (path_args.len < 1) {
                std.debug.print("Usage: mg fs read <path>\n", .{});
                return;
            }
            try fsRead(path_args[0], dry_run);
        } else if (std.mem.eql(u8, fs_cmd, "write") or std.mem.eql(u8, fs_cmd, "echo")) {
            if (path_args.len < 2) {
                std.debug.print("Usage: mg fs write <path> <content>\n", .{});
                return;
            }
            try fsWrite(path_args[0], path_args[1], dry_run);
        } else {
            std.debug.print("Unknown fs subcommand: {s}\n", .{fs_cmd});
        }
        return;
    }

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
