const std = @import("std");
const fs = @import("../fs.zig");

const Self = @This();

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
        std.debug.print("Unknown fs subcommand: {s}\n", .{cmd});
    }
}

fn handleCreate(args: []const [:0]u8, dry_run: bool) !void {
    if (args.len < 1) {
        std.debug.print("Usage: mg fs create <path> [--dir] [--recursive|-r]\n", .{});
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

fn handleRemove(args: []const [:0]u8, dry_run: bool) !void {
    if (args.len < 1) {
        std.debug.print("Usage: mg fs remove <path> [--recursive|-r]\n", .{});
        return;
    }
    var path_idx: usize = 0;
    for (args, 0..) |p, idx| {
        if (std.mem.startsWith(u8, p, "--")) continue;
        path_idx = idx;
    }
    const paths = args[path_idx..];
    for (paths) |p| {
        if (std.mem.startsWith(u8, p, "--")) continue;
        fs.fsRemove(p, true, dry_run) catch {};
    }
}

fn handleCopy(args: []const [:0]u8, dry_run: bool) !void {
    if (args.len < 2) {
        std.debug.print("Usage: mg fs copy <src> <dst> [--recursive|-r]\n", .{});
        return;
    }
    const src = args[0];
    const dst = args[1];
    fs.fsCopyExtended(src, dst, true, dry_run) catch {};
}

fn handleMove(args: []const [:0]u8, dry_run: bool) !void {
    if (args.len < 2) {
        std.debug.print("Usage: mg fs move <src> <dst>\n", .{});
        return;
    }
    fs.fsMove(args[0], args[1], dry_run) catch {};
}

fn handleList(args: []const [:0]u8, dry_run: bool) !void {
    const path = if (args.len > 0) args[0] else ".";
    fs.fsList(path, dry_run) catch {};
}

fn handleExists(args: []const [:0]u8, dry_run: bool) void {
    if (args.len < 1) {
        std.debug.print("Usage: mg fs exists <path>\n", .{});
        return;
    }
    fs.fsExists(args[0], dry_run);
}

fn handleRead(args: []const [:0]u8, dry_run: bool) !void {
    if (args.len < 1) {
        std.debug.print("Usage: mg fs read <path>\n", .{});
        return;
    }
    fs.fsRead(args[0], dry_run) catch {};
}

fn handleWrite(args: []const [:0]u8, dry_run: bool) !void {
    if (args.len < 2) {
        std.debug.print("Usage: mg fs write <path> <content>\n", .{});
        return;
    }
    fs.fsWrite(args[0], args[1], dry_run) catch {};
}
