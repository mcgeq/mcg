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

const ParsedCreateArgs = struct {
    force_dir: bool = false,
    recursive: bool = false,
    paths: std.ArrayList([:0]const u8),

    fn init() ParsedCreateArgs {
        return .{
            .paths = .empty,
        };
    }

    fn deinit(self: *ParsedCreateArgs, allocator: std.mem.Allocator) void {
        self.paths.deinit(allocator);
    }
};

const ParsedRemoveArgs = struct {
    recursive: bool = false,
    paths: std.ArrayList([:0]const u8),

    fn init() ParsedRemoveArgs {
        return .{
            .paths = .empty,
        };
    }

    fn deinit(self: *ParsedRemoveArgs, allocator: std.mem.Allocator) void {
        self.paths.deinit(allocator);
    }
};

const ParsedCopyArgs = struct {
    recursive: bool = false,
    src: ?[:0]const u8 = null,
    dst: ?[:0]const u8 = null,
    extra_positionals: usize = 0,
};

const DefaultFsOps = struct {
    fn createExtended(
        _: *const @This(),
        path: []const u8,
        is_dir: bool,
        recursive: bool,
        dry_run: bool,
    ) !void {
        try fs.fsCreateExtended(path, is_dir, recursive, dry_run);
    }

    fn remove(
        _: *const @This(),
        path: []const u8,
        recursive: bool,
        dry_run: bool,
    ) !void {
        try fs.fsRemove(path, recursive, dry_run);
    }

    fn removeWildcard(
        _: *const @This(),
        pattern: []const u8,
        recursive: bool,
        dry_run: bool,
    ) !void {
        try fs.fsRemoveWildcard(pattern, recursive, dry_run);
    }

    fn copyExtended(
        _: *const @This(),
        src: []const u8,
        dst: []const u8,
        recursive: bool,
        dry_run: bool,
    ) !void {
        try fs.fsCopyExtended(src, dst, recursive, dry_run);
    }

    fn move(
        _: *const @This(),
        src: []const u8,
        dst: []const u8,
        dry_run: bool,
    ) !void {
        try fs.fsMove(src, dst, dry_run);
    }

    fn list(
        _: *const @This(),
        path: []const u8,
        dry_run: bool,
    ) !void {
        try fs.fsList(path, dry_run);
    }

    fn listWildcard(
        _: *const @This(),
        pattern: []const u8,
        dry_run: bool,
    ) !void {
        try fs.fsListWildcard(pattern, dry_run);
    }

    fn exists(
        _: *const @This(),
        path: []const u8,
        dry_run: bool,
    ) void {
        fs.fsExists(path, dry_run);
    }

    fn read(
        _: *const @This(),
        path: []const u8,
        dry_run: bool,
    ) !void {
        try fs.fsRead(path, dry_run);
    }

    fn write(
        _: *const @This(),
        path: []const u8,
        content: []const u8,
        dry_run: bool,
    ) !void {
        try fs.fsWrite(path, content, dry_run);
    }
};

fn pathLooksLikeDirectory(path: []const u8) bool {
    if (path.len == 0) return false;

    const last = path[path.len - 1];
    return last == '/' or last == '\\';
}

fn parseCreateArgs(allocator: std.mem.Allocator, args: []const [:0]const u8) !ParsedCreateArgs {
    var parsed = ParsedCreateArgs.init();
    errdefer parsed.deinit(allocator);

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--dir")) {
            parsed.force_dir = true;
        } else if (std.mem.eql(u8, arg, "--recursive") or std.mem.eql(u8, arg, "-r")) {
            parsed.recursive = true;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            continue;
        } else {
            try parsed.paths.append(allocator, arg);
        }
    }

    return parsed;
}

fn parseRemoveArgs(allocator: std.mem.Allocator, args: []const [:0]const u8) !ParsedRemoveArgs {
    var parsed = ParsedRemoveArgs.init();
    errdefer parsed.deinit(allocator);

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--recursive") or std.mem.eql(u8, arg, "-r") or std.mem.eql(u8, arg, "-p")) {
            parsed.recursive = true;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            continue;
        } else {
            try parsed.paths.append(allocator, arg);
        }
    }

    return parsed;
}

fn parseCopyArgs(args: []const [:0]const u8) ParsedCopyArgs {
    var parsed: ParsedCopyArgs = .{};

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--recursive") or std.mem.eql(u8, arg, "-r")) {
            parsed.recursive = true;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            continue;
        } else if (parsed.src == null) {
            parsed.src = arg;
        } else if (parsed.dst == null) {
            parsed.dst = arg;
        } else {
            parsed.extra_positionals += 1;
        }
    }

    return parsed;
}

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
pub fn handleCommand(cmd: []const u8, args: []const [:0]const u8, dry_run: bool) !void {
    var ops = DefaultFsOps{};
    try handleCommandWithOps(&ops, cmd, args, dry_run);
}

fn handleCommandWithOps(
    ops: anytype,
    cmd: []const u8,
    args: []const [:0]const u8,
    dry_run: bool,
) !void {
    if (std.mem.eql(u8, cmd, "create") or std.mem.eql(u8, cmd, "c") or std.mem.eql(u8, cmd, "touch")) {
        try handleCreateWithOps(ops, args, dry_run);
    } else if (std.mem.eql(u8, cmd, "remove") or std.mem.eql(u8, cmd, "rm") or std.mem.eql(u8, cmd, "r")) {
        try handleRemoveWithOps(ops, args, dry_run);
    } else if (std.mem.eql(u8, cmd, "copy") or std.mem.eql(u8, cmd, "cp") or std.mem.eql(u8, cmd, "y")) {
        try handleCopyWithOps(ops, args, dry_run);
    } else if (std.mem.eql(u8, cmd, "move") or std.mem.eql(u8, cmd, "mv") or std.mem.eql(u8, cmd, "m")) {
        try handleMoveWithOps(ops, args, dry_run);
    } else if (std.mem.eql(u8, cmd, "list") or std.mem.eql(u8, cmd, "ls")) {
        try handleListWithOps(ops, args, dry_run);
    } else if (std.mem.eql(u8, cmd, "exists") or std.mem.eql(u8, cmd, "test")) {
        handleExistsWithOps(ops, args, dry_run);
    } else if (std.mem.eql(u8, cmd, "read") or std.mem.eql(u8, cmd, "cat")) {
        try handleReadWithOps(ops, args, dry_run);
    } else if (std.mem.eql(u8, cmd, "write") or std.mem.eql(u8, cmd, "echo")) {
        try handleWriteWithOps(ops, args, dry_run);
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
fn handleCreate(args: []const [:0]const u8, dry_run: bool) !void {
    var ops = DefaultFsOps{};
    try handleCreateWithOps(&ops, args, dry_run);
}

fn handleCreateWithOps(ops: anytype, args: []const [:0]const u8, dry_run: bool) !void {
    var parsed = try parseCreateArgs(std.heap.page_allocator, args);
    defer parsed.deinit(std.heap.page_allocator);

    if (parsed.paths.items.len < 1) {
        logger.info("Usage: mg fs create <path> [--dir] [--recursive|-r]\n", .{});
        return;
    }

    for (parsed.paths.items) |path| {
        const is_dir = parsed.force_dir or pathLooksLikeDirectory(path);
        ops.createExtended(path, is_dir, parsed.recursive, dry_run) catch {};
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
fn handleRemove(args: []const [:0]const u8, dry_run: bool) !void {
    var ops = DefaultFsOps{};
    try handleRemoveWithOps(&ops, args, dry_run);
}

fn handleRemoveWithOps(ops: anytype, args: []const [:0]const u8, dry_run: bool) !void {
    var parsed = try parseRemoveArgs(std.heap.page_allocator, args);
    defer parsed.deinit(std.heap.page_allocator);

    if (parsed.paths.items.len < 1) {
        logger.info("Usage: mg fs remove <path> [--recursive|-r|-p]\n", .{});
        return;
    }

    for (parsed.paths.items) |path| {
        const has_wildcard = std.mem.indexOfAny(u8, path, "*?") != null;
        if (has_wildcard) {
            ops.removeWildcard(path, parsed.recursive, dry_run) catch {};
        } else {
            ops.remove(path, parsed.recursive, dry_run) catch {};
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
fn handleCopy(args: []const [:0]const u8, dry_run: bool) !void {
    var ops = DefaultFsOps{};
    try handleCopyWithOps(&ops, args, dry_run);
}

fn handleCopyWithOps(ops: anytype, args: []const [:0]const u8, dry_run: bool) !void {
    const parsed = parseCopyArgs(args);
    if (parsed.src == null or parsed.dst == null or parsed.extra_positionals != 0) {
        logger.info("Usage: mg fs copy <src> <dst> [--recursive|-r]\n", .{});
        return;
    }

    ops.copyExtended(parsed.src.?, parsed.dst.?, parsed.recursive, dry_run) catch {};
}

/// Handles the "move" subcommand for moving or renaming files/directories.
///
/// Usage: mg fs move <src> <dst>
///
/// Parameters:
///   - args: Arguments slice with source and destination paths
///   - dry_run: If true, preview without executing
fn handleMove(args: []const [:0]const u8, dry_run: bool) !void {
    var ops = DefaultFsOps{};
    try handleMoveWithOps(&ops, args, dry_run);
}

fn handleMoveWithOps(ops: anytype, args: []const [:0]const u8, dry_run: bool) !void {
    if (args.len != 2) {
        logger.info("Usage: mg fs move <src> <dst>\n", .{});
        return;
    }
    ops.move(args[0], args[1], dry_run) catch {};
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
fn handleList(args: []const [:0]const u8, dry_run: bool) !void {
    var ops = DefaultFsOps{};
    try handleListWithOps(&ops, args, dry_run);
}

fn handleListWithOps(ops: anytype, args: []const [:0]const u8, dry_run: bool) !void {
    if (args.len > 1) {
        logger.info("Usage: mg fs list [path]\n", .{});
        return;
    }

    const path = if (args.len > 0) args[0] else ".";
    const has_wildcard = std.mem.indexOfAny(u8, path, "*?") != null;
    if (has_wildcard) {
        ops.listWildcard(path, dry_run) catch {};
    } else {
        ops.list(path, dry_run) catch {};
    }
}

/// Handles the "exists" subcommand for checking path existence.
///
/// Usage: mg fs exists <path>
///
/// Parameters:
///   - args: Arguments slice containing at least one path
///   - dry_run: If true, preview without executing
fn handleExists(args: []const [:0]const u8, dry_run: bool) void {
    var ops = DefaultFsOps{};
    handleExistsWithOps(&ops, args, dry_run);
}

fn handleExistsWithOps(ops: anytype, args: []const [:0]const u8, dry_run: bool) void {
    if (args.len != 1) {
        logger.info("Usage: mg fs exists <path>\n", .{});
        return;
    }
    ops.exists(args[0], dry_run);
}

/// Handles the "read" subcommand for displaying file contents.
///
/// Usage: mg fs read <path>
///
/// Parameters:
///   - args: Arguments slice containing the file path
///   - dry_run: If true, preview without executing
fn handleRead(args: []const [:0]const u8, dry_run: bool) !void {
    var ops = DefaultFsOps{};
    try handleReadWithOps(&ops, args, dry_run);
}

fn handleReadWithOps(ops: anytype, args: []const [:0]const u8, dry_run: bool) !void {
    if (args.len != 1) {
        logger.info("Usage: mg fs read <path>\n", .{});
        return;
    }
    ops.read(args[0], dry_run) catch {};
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
fn handleWrite(args: []const [:0]const u8, dry_run: bool) !void {
    var ops = DefaultFsOps{};
    try handleWriteWithOps(&ops, args, dry_run);
}

fn handleWriteWithOps(ops: anytype, args: []const [:0]const u8, dry_run: bool) !void {
    if (args.len != 2) {
        logger.info("Usage: mg fs write <path> <content>\n", .{});
        return;
    }
    ops.write(args[0], args[1], dry_run) catch {};
}

test "pathLooksLikeDirectory recognizes trailing separators" {
    try std.testing.expect(pathLooksLikeDirectory("src/"));
    try std.testing.expect(pathLooksLikeDirectory("src\\"));
    try std.testing.expect(!pathLooksLikeDirectory("src"));
}

test "parseCreateArgs supports multiple paths and flags" {
    var parsed = try parseCreateArgs(std.testing.allocator, &.{
        "--dir",
        "src/",
        "docs/",
        "-r",
        "notes.txt",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expect(parsed.force_dir);
    try std.testing.expect(parsed.recursive);
    try std.testing.expectEqual(@as(usize, 3), parsed.paths.items.len);
    try std.testing.expectEqualStrings("src/", parsed.paths.items[0]);
    try std.testing.expectEqualStrings("docs/", parsed.paths.items[1]);
    try std.testing.expectEqualStrings("notes.txt", parsed.paths.items[2]);
}

test "parseRemoveArgs keeps multiple positional targets" {
    var parsed = try parseRemoveArgs(std.testing.allocator, &.{
        "old.log",
        "-p",
        "tmp/",
        "cache/*.tmp",
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expect(parsed.recursive);
    try std.testing.expectEqual(@as(usize, 3), parsed.paths.items.len);
    try std.testing.expectEqualStrings("old.log", parsed.paths.items[0]);
    try std.testing.expectEqualStrings("tmp/", parsed.paths.items[1]);
    try std.testing.expectEqualStrings("cache/*.tmp", parsed.paths.items[2]);
}

test "parseCopyArgs honors recursive flag and exact two paths" {
    const parsed = parseCopyArgs(&.{
        "--recursive",
        "src/",
        "backup/",
    });

    try std.testing.expect(parsed.recursive);
    try std.testing.expectEqualStrings("src/", parsed.src.?);
    try std.testing.expectEqualStrings("backup/", parsed.dst.?);
    try std.testing.expectEqual(@as(usize, 0), parsed.extra_positionals);
}

test "parseCopyArgs tracks extra positional arguments" {
    const parsed = parseCopyArgs(&.{
        "a.txt",
        "b.txt",
        "c.txt",
    });

    try std.testing.expectEqualStrings("a.txt", parsed.src.?);
    try std.testing.expectEqualStrings("b.txt", parsed.dst.?);
    try std.testing.expectEqual(@as(usize, 1), parsed.extra_positionals);
}

const RecordedCall = union(enum) {
    create_extended: struct {
        path: []const u8,
        is_dir: bool,
        recursive: bool,
        dry_run: bool,
    },
    remove: struct {
        path: []const u8,
        recursive: bool,
        dry_run: bool,
    },
    remove_wildcard: struct {
        pattern: []const u8,
        recursive: bool,
        dry_run: bool,
    },
    copy_extended: struct {
        src: []const u8,
        dst: []const u8,
        recursive: bool,
        dry_run: bool,
    },
    move: struct {
        src: []const u8,
        dst: []const u8,
        dry_run: bool,
    },
    list: struct {
        path: []const u8,
        dry_run: bool,
    },
    list_wildcard: struct {
        pattern: []const u8,
        dry_run: bool,
    },
    exists: struct {
        path: []const u8,
        dry_run: bool,
    },
    read: struct {
        path: []const u8,
        dry_run: bool,
    },
    write: struct {
        path: []const u8,
        content: []const u8,
        dry_run: bool,
    },
};

const RecordingFsOps = struct {
    calls: [16]RecordedCall = undefined,
    len: usize = 0,

    fn append(self: *@This(), call: RecordedCall) void {
        std.debug.assert(self.len < self.calls.len);
        self.calls[self.len] = call;
        self.len += 1;
    }

    fn createExtended(
        self: *@This(),
        path: []const u8,
        is_dir: bool,
        recursive: bool,
        dry_run: bool,
    ) !void {
        self.append(.{
            .create_extended = .{
                .path = path,
                .is_dir = is_dir,
                .recursive = recursive,
                .dry_run = dry_run,
            },
        });
    }

    fn remove(
        self: *@This(),
        path: []const u8,
        recursive: bool,
        dry_run: bool,
    ) !void {
        self.append(.{
            .remove = .{
                .path = path,
                .recursive = recursive,
                .dry_run = dry_run,
            },
        });
    }

    fn removeWildcard(
        self: *@This(),
        pattern: []const u8,
        recursive: bool,
        dry_run: bool,
    ) !void {
        self.append(.{
            .remove_wildcard = .{
                .pattern = pattern,
                .recursive = recursive,
                .dry_run = dry_run,
            },
        });
    }

    fn copyExtended(
        self: *@This(),
        src: []const u8,
        dst: []const u8,
        recursive: bool,
        dry_run: bool,
    ) !void {
        self.append(.{
            .copy_extended = .{
                .src = src,
                .dst = dst,
                .recursive = recursive,
                .dry_run = dry_run,
            },
        });
    }

    fn move(
        self: *@This(),
        src: []const u8,
        dst: []const u8,
        dry_run: bool,
    ) !void {
        self.append(.{
            .move = .{
                .src = src,
                .dst = dst,
                .dry_run = dry_run,
            },
        });
    }

    fn list(
        self: *@This(),
        path: []const u8,
        dry_run: bool,
    ) !void {
        self.append(.{
            .list = .{
                .path = path,
                .dry_run = dry_run,
            },
        });
    }

    fn listWildcard(
        self: *@This(),
        pattern: []const u8,
        dry_run: bool,
    ) !void {
        self.append(.{
            .list_wildcard = .{
                .pattern = pattern,
                .dry_run = dry_run,
            },
        });
    }

    fn exists(
        self: *@This(),
        path: []const u8,
        dry_run: bool,
    ) void {
        self.append(.{
            .exists = .{
                .path = path,
                .dry_run = dry_run,
            },
        });
    }

    fn read(
        self: *@This(),
        path: []const u8,
        dry_run: bool,
    ) !void {
        self.append(.{
            .read = .{
                .path = path,
                .dry_run = dry_run,
            },
        });
    }

    fn write(
        self: *@This(),
        path: []const u8,
        content: []const u8,
        dry_run: bool,
    ) !void {
        self.append(.{
            .write = .{
                .path = path,
                .content = content,
                .dry_run = dry_run,
            },
        });
    }

    fn slice(self: *const @This()) []const RecordedCall {
        return self.calls[0..self.len];
    }
};

fn expectCreateCall(
    call: RecordedCall,
    path: []const u8,
    is_dir: bool,
    recursive: bool,
    dry_run: bool,
) !void {
    switch (call) {
        .create_extended => |recorded| {
            try std.testing.expectEqualStrings(path, recorded.path);
            try std.testing.expectEqual(is_dir, recorded.is_dir);
            try std.testing.expectEqual(recursive, recorded.recursive);
            try std.testing.expectEqual(dry_run, recorded.dry_run);
        },
        else => return error.TestUnexpectedResult,
    }
}

fn expectRemoveCall(
    call: RecordedCall,
    path: []const u8,
    recursive: bool,
    dry_run: bool,
) !void {
    switch (call) {
        .remove => |recorded| {
            try std.testing.expectEqualStrings(path, recorded.path);
            try std.testing.expectEqual(recursive, recorded.recursive);
            try std.testing.expectEqual(dry_run, recorded.dry_run);
        },
        else => return error.TestUnexpectedResult,
    }
}

fn expectRemoveWildcardCall(
    call: RecordedCall,
    pattern: []const u8,
    recursive: bool,
    dry_run: bool,
) !void {
    switch (call) {
        .remove_wildcard => |recorded| {
            try std.testing.expectEqualStrings(pattern, recorded.pattern);
            try std.testing.expectEqual(recursive, recorded.recursive);
            try std.testing.expectEqual(dry_run, recorded.dry_run);
        },
        else => return error.TestUnexpectedResult,
    }
}

fn expectCopyCall(
    call: RecordedCall,
    src: []const u8,
    dst: []const u8,
    recursive: bool,
    dry_run: bool,
) !void {
    switch (call) {
        .copy_extended => |recorded| {
            try std.testing.expectEqualStrings(src, recorded.src);
            try std.testing.expectEqualStrings(dst, recorded.dst);
            try std.testing.expectEqual(recursive, recorded.recursive);
            try std.testing.expectEqual(dry_run, recorded.dry_run);
        },
        else => return error.TestUnexpectedResult,
    }
}

fn expectListCall(call: RecordedCall, path: []const u8, dry_run: bool) !void {
    switch (call) {
        .list => |recorded| {
            try std.testing.expectEqualStrings(path, recorded.path);
            try std.testing.expectEqual(dry_run, recorded.dry_run);
        },
        else => return error.TestUnexpectedResult,
    }
}

fn expectListWildcardCall(call: RecordedCall, pattern: []const u8, dry_run: bool) !void {
    switch (call) {
        .list_wildcard => |recorded| {
            try std.testing.expectEqualStrings(pattern, recorded.pattern);
            try std.testing.expectEqual(dry_run, recorded.dry_run);
        },
        else => return error.TestUnexpectedResult,
    }
}

fn expectMoveCall(call: RecordedCall, src: []const u8, dst: []const u8, dry_run: bool) !void {
    switch (call) {
        .move => |recorded| {
            try std.testing.expectEqualStrings(src, recorded.src);
            try std.testing.expectEqualStrings(dst, recorded.dst);
            try std.testing.expectEqual(dry_run, recorded.dry_run);
        },
        else => return error.TestUnexpectedResult,
    }
}

fn expectExistsCall(call: RecordedCall, path: []const u8, dry_run: bool) !void {
    switch (call) {
        .exists => |recorded| {
            try std.testing.expectEqualStrings(path, recorded.path);
            try std.testing.expectEqual(dry_run, recorded.dry_run);
        },
        else => return error.TestUnexpectedResult,
    }
}

fn expectReadCall(call: RecordedCall, path: []const u8, dry_run: bool) !void {
    switch (call) {
        .read => |recorded| {
            try std.testing.expectEqualStrings(path, recorded.path);
            try std.testing.expectEqual(dry_run, recorded.dry_run);
        },
        else => return error.TestUnexpectedResult,
    }
}

fn expectWriteCall(
    call: RecordedCall,
    path: []const u8,
    content: []const u8,
    dry_run: bool,
) !void {
    switch (call) {
        .write => |recorded| {
            try std.testing.expectEqualStrings(path, recorded.path);
            try std.testing.expectEqualStrings(content, recorded.content);
            try std.testing.expectEqual(dry_run, recorded.dry_run);
        },
        else => return error.TestUnexpectedResult,
    }
}

fn muteLogger() logger.LogLevel {
    const log = logger.getLogger();
    const old_level = log.level;
    log.level = .off;
    return old_level;
}

test "handleCommand routes create alias across multiple paths" {
    var ops = RecordingFsOps{};

    try handleCommandWithOps(&ops, "touch", &.{
        "src/",
        "-r",
        "notes.txt",
    }, true);

    try std.testing.expectEqual(@as(usize, 2), ops.slice().len);
    try expectCreateCall(ops.slice()[0], "src/", true, true, true);
    try expectCreateCall(ops.slice()[1], "notes.txt", false, true, true);
}

test "handleCommand routes remove wildcard and plain targets separately" {
    var ops = RecordingFsOps{};

    try handleCommandWithOps(&ops, "rm", &.{
        "-r",
        "cache/",
        "logs/*.tmp",
    }, false);

    try std.testing.expectEqual(@as(usize, 2), ops.slice().len);
    try expectRemoveCall(ops.slice()[0], "cache/", true, false);
    try expectRemoveWildcardCall(ops.slice()[1], "logs/*.tmp", true, false);
}

test "handleCommand routes copy alias and rejects extra positionals" {
    var ops = RecordingFsOps{};
    try handleCommandWithOps(&ops, "cp", &.{
        "--recursive",
        "src/",
        "backup/",
    }, false);

    try std.testing.expectEqual(@as(usize, 1), ops.slice().len);
    try expectCopyCall(ops.slice()[0], "src/", "backup/", true, false);

    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var invalid_ops = RecordingFsOps{};
    try handleCommandWithOps(&invalid_ops, "copy", &.{
        "a.txt",
        "b.txt",
        "c.txt",
    }, false);

    try std.testing.expectEqual(@as(usize, 0), invalid_ops.slice().len);
}

test "handleCommand routes list variants by wildcard presence" {
    var plain_ops = RecordingFsOps{};
    try handleCommandWithOps(&plain_ops, "list", &.{"src"}, true);

    try std.testing.expectEqual(@as(usize, 1), plain_ops.slice().len);
    try expectListCall(plain_ops.slice()[0], "src", true);

    var wildcard_ops = RecordingFsOps{};
    try handleCommandWithOps(&wildcard_ops, "ls", &.{"*.zig"}, false);

    try std.testing.expectEqual(@as(usize, 1), wildcard_ops.slice().len);
    try expectListWildcardCall(wildcard_ops.slice()[0], "*.zig", false);
}

test "handleCommand routes exists read write and move aliases" {
    var ops = RecordingFsOps{};

    handleCommandWithOps(&ops, "test", &.{"config.json"}, true) catch unreachable;
    try handleCommandWithOps(&ops, "cat", &.{"README.md"}, false);
    try handleCommandWithOps(&ops, "echo", &.{ "notes.txt", "hello" }, true);
    try handleCommandWithOps(&ops, "mv", &.{ "draft.txt", "final.txt" }, false);

    try std.testing.expectEqual(@as(usize, 4), ops.slice().len);
    try expectExistsCall(ops.slice()[0], "config.json", true);
    try expectReadCall(ops.slice()[1], "README.md", false);
    try expectWriteCall(ops.slice()[2], "notes.txt", "hello", true);
    try expectMoveCall(ops.slice()[3], "draft.txt", "final.txt", false);
}

test "handleCommand rejects invalid arity for single-target fs commands" {
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var list_ops = RecordingFsOps{};
    try handleCommandWithOps(&list_ops, "list", &.{ "src", "extra" }, false);
    try std.testing.expectEqual(@as(usize, 0), list_ops.slice().len);

    var exists_ops = RecordingFsOps{};
    handleCommandWithOps(&exists_ops, "exists", &.{ "a.txt", "b.txt" }, false) catch unreachable;
    try std.testing.expectEqual(@as(usize, 0), exists_ops.slice().len);

    var read_ops = RecordingFsOps{};
    try handleCommandWithOps(&read_ops, "read", &.{ "a.txt", "b.txt" }, false);
    try std.testing.expectEqual(@as(usize, 0), read_ops.slice().len);

    var write_ops = RecordingFsOps{};
    try handleCommandWithOps(&write_ops, "write", &.{ "a.txt", "hello", "world" }, false);
    try std.testing.expectEqual(@as(usize, 0), write_ops.slice().len);

    var move_ops = RecordingFsOps{};
    try handleCommandWithOps(&move_ops, "move", &.{ "a.txt", "b.txt", "c.txt" }, false);
    try std.testing.expectEqual(@as(usize, 0), move_ops.slice().len);
}
