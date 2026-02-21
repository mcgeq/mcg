/// File system command handlers.
///
/// This module parses and dispatches file system subcommands to the appropriate
/// handler functions. Each handler supports multiple aliases for convenience.
///
/// Supported Commands and Aliases:
///   | Command   | Aliases        | Description                    |
///   |-----------|----------------|--------------------------------|
///   | create    | c, touch       | Create file or directory       |
///   | remove    | r, rm          | Remove file or directory       |
///   | copy      | cp, y          | Copy file or directory         |
///   | move      | mv, m          | Move/rename file or directory  |
///   | list      | ls             | List directory contents        |
///   | exists    | test           | Check if path exists           |
///   | read      | cat            | Read and display file contents |
///   | write     | echo           | Write content to a file        |
const std = @import("std");
const fs = @import("core.zig");
const logger = @import("../core/logger.zig");

const Self = @This();

/// Dispatches a file system subcommand to the appropriate handler.
///
/// Parameters:
///   - cmd: The subcommand string (matched against known commands and aliases)
///   - args: Argument slice for the subcommand
///   - dry_run: If true, preview operations without executing
///
/// Behavior:
///   Matches cmd against all known commands (case-sensitive exact match).
///   If no match is found, prints an error message.
pub fn handleCommand(cmd: []const u8, args: []const [:0]u8, dry_run: bool) !void {
    if (std.mem.eql(u8, cmd, "create") or std.mem.eql(u8, cmd, "c") or std.mem.eql(u8, cmd, "touch")) {
        try handleCreate(args, dry_run);
    } else if (std.mem.eql(u8, cmd, "remove") or std.mem.eql(u8, cmd, "rm") or std.mem.eql(u8, cmd, "r")) {
        try handleRemove(args, dry_run);
    } else if (std.mem.eql(u8, cmd, "copy") or std.mem.eql(u8, cmd, "cp") or std.mem.eql(u8, cmd, "y")) {
        try handleCopy(args, dry_run);
    } else if (std.mem.eql(u8, cmd, "move") or std.mem.eql(u8, cmd, "mv") or std.mem.eql(u8, cmd, "m")) {
        try handleMove(args, dry_run);
    } else if (std.mem.eql(u8, cmd, "list") or std.mem.eql(u8, cmd, "ls")) {
        try handleList(args, dry_run);
    } else if (std.mem.eql(u8, cmd, "exists") or std.mem.eql(u8, cmd, "test")) {
        handleExists(args, dry_run);
    } else if (std.mem.eql(u8, cmd, "read") or std.mem.eql(u8, cmd, "cat")) {
        try handleRead(args, dry_run);
    } else if (std.mem.eql(u8, cmd, "write") or std.mem.eql(u8, cmd, "echo")) {
        try handleWrite(args, dry_run);
    } else {
        logger.err("Unknown fs subcommand: {s}\n", .{cmd});
    }
}

/// Handles the "create" subcommand for creating files or directories.
///
/// Usage: mg fs create <path> [--dir] [--recursive|-r]
///
/// Parameters:
///   - args: Arguments slice containing at least one path
///   - dry_run: If true, preview without executing
///
/// Options:
///   --dir: Force creation as a directory
///   --recursive, -r: Create parent directories as needed
///
/// Note:
///   Automatically detects directory creation if path ends with "/".
///   Multiple paths can be specified to create multiple items.
fn handleCreate(args: []const [:0]u8, dry_run: bool) !void {
    if (args.len < 1) {
        logger.info("Usage: mg fs create <path> [--dir] [--recursive|-r]\n", .{});
        return;
    }
    var is_dir = false;
    var path_idx: usize = 0;
    for (args, 0..) |p, idx| {
        if (std.mem.eql(u8, p, "--dir")) {
            is_dir = true;
        } else if (std.mem.startsWith(u8, p, "--")) {
            continue;
        } else {
            path_idx = idx;
        }
    }
    const paths = args[path_idx..];
    for (paths) |p| {
        if (std.mem.startsWith(u8, p, "--")) continue;
        fs.fsCreateExtended(p, is_dir, true, dry_run) catch {};
    }
}

/// Handles the "remove" subcommand for deleting files or directories.
///
/// Usage: mg fs remove <path> [--recursive|-r]
///
/// Parameters:
///   - args: Arguments slice containing at least one path
///   - dry_run: If true, preview without executing
///
/// Options:
///   --recursive, -r: Remove directories and their contents recursively
fn handleRemove(args: []const [:0]u8, dry_run: bool) !void {
    if (args.len < 1) {
        logger.info("Usage: mg fs remove <path> [--recursive|-r|-p]\n", .{});
        return;
    }
    var is_recursive = false;
    var path_idx: usize = 0;
    for (args, 0..) |p, idx| {
        if (std.mem.eql(u8, p, "--recursive") or std.mem.eql(u8, p, "-r") or std.mem.eql(u8, p, "-p")) {
            is_recursive = true;
        } else if (std.mem.startsWith(u8, p, "-")) {
            continue;
        } else {
            path_idx = idx;
        }
    }
    const paths = args[path_idx..];
    for (paths) |p| {
        if (std.mem.startsWith(u8, p, "-")) continue;
        const has_wildcard = std.mem.indexOfAny(u8, p, "*?") != null;
        if (has_wildcard) {
            fs.fsRemoveWildcard(p, is_recursive, dry_run) catch {};
        } else {
            fs.fsRemove(p, is_recursive, dry_run) catch {};
        }
    }
}

/// Handles the "copy" subcommand for copying files or directories.
///
/// Usage: mg fs copy <src> <dst> [--recursive|-r]
///
/// Parameters:
///   - args: Arguments slice with source and destination paths
///   - dry_run: If true, preview without executing
///
/// Note:
///   Requires exactly 2 arguments: source and destination.
fn handleCopy(args: []const [:0]u8, dry_run: bool) !void {
    if (args.len < 2) {
        logger.info("Usage: mg fs copy <src> <dst> [--recursive|-r]\n", .{});
        return;
    }
    const src = args[0];
    const dst = args[1];
    fs.fsCopyExtended(src, dst, true, dry_run) catch {};
}

/// Handles the "move" subcommand for moving or renaming files/directories.
///
/// Usage: mg fs move <src> <dst>
///
/// Parameters:
///   - args: Arguments slice with source and destination paths
///   - dry_run: If true, preview without executing
fn handleMove(args: []const [:0]u8, dry_run: bool) !void {
    if (args.len < 2) {
        logger.info("Usage: mg fs move <src> <dst>\n", .{});
        return;
    }
    fs.fsMove(args[0], args[1], dry_run) catch {};
}

/// Handles the "list" subcommand for listing directory contents.
///
/// Usage: mg fs list [path]
///
/// Parameters:
///   - args: Optional path argument (defaults to ".")
///   - dry_run: If true, preview without executing
///
/// Output:
///   Lists files and directories. Directories are suffixed with "/".
fn handleList(args: []const [:0]u8, dry_run: bool) !void {
    const path = if (args.len > 0) args[0] else ".";
    const has_wildcard = std.mem.indexOfAny(u8, path, "*?") != null;
    if (has_wildcard) {
        fs.fsListWildcard(path, dry_run) catch {};
    } else {
        fs.fsList(path, dry_run) catch {};
    }
}

/// Handles the "exists" subcommand for checking path existence.
///
/// Usage: mg fs exists <path>
///
/// Parameters:
///   - args: Arguments slice containing at least one path
///   - dry_run: If true, preview without executing
fn handleExists(args: []const [:0]u8, dry_run: bool) void {
    if (args.len < 1) {
        logger.info("Usage: mg fs exists <path>\n", .{});
        return;
    }
    fs.fsExists(args[0], dry_run);
}

/// Handles the "read" subcommand for displaying file contents.
///
/// Usage: mg fs read <path>
///
/// Parameters:
///   - args: Arguments slice containing the file path
///   - dry_run: If true, preview without executing
fn handleRead(args: []const [:0]u8, dry_run: bool) !void {
    if (args.len < 1) {
        logger.info("Usage: mg fs read <path>\n", .{});
        return;
    }
    fs.fsRead(args[0], dry_run) catch {};
}

/// Handles the "write" subcommand for creating or overwriting files.
///
/// Usage: mg fs write <path> <content>
///
/// Parameters:
///   - args: Arguments slice with path and content
///   - dry_run: If true, preview without executing
///
/// Note:
///   Requires exactly 2 arguments. Content is written verbatim.
fn handleWrite(args: []const [:0]u8, dry_run: bool) !void {
    if (args.len < 2) {
        logger.info("Usage: mg fs write <path> <content>\n", .{});
        return;
    }
    fs.fsWrite(args[0], args[1], dry_run) catch {};
}
