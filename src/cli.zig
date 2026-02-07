const std = @import("std");
const fs = @import("fs/mod.zig");

pub const ParseResult = enum {
    help,
    fs,
    pkg,
    none,
};

pub const Options = struct {
    dry_run: bool = false,
};

pub fn printHelp() void {
    std.debug.print("mg - Multi-package manager CLI\n", .{});
    std.debug.print("Usage: mg [options] <command> [args]\n", .{});
    std.debug.print("Commands: add, remove, upgrade, install, analyze\n", .{});
    std.debug.print("FS Commands: fs create, fs remove, fs copy, fs move, fs list, fs read, fs write\n", .{});
    std.debug.print("Options: --dry-run, --help\n", .{});
}

pub fn parseOptions(args: []const [:0]u8) Options {
    var opts: Options = .{};
    for (args) |arg| {
        if (std.mem.startsWith(u8, arg, "--")) {
            const opt = arg[2..];
            if (std.mem.eql(u8, opt, "dry-run") or std.mem.eql(u8, opt, "d")) {
                opts.dry_run = true;
            } else if (std.mem.eql(u8, opt, "help") or std.mem.eql(u8, opt, "h")) {
                opts.dry_run = false;
            }
        }
    }
    return opts;
}

pub fn parse(args: []const [:0]u8) ParseResult {
    var i: usize = 1;
    var opts: Options = .{};

    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.startsWith(u8, arg, "--")) {
            const opt = arg[2..];
            if (std.mem.eql(u8, opt, "dry-run") or std.mem.eql(u8, opt, "d")) {
                opts.dry_run = true;
            } else if (std.mem.eql(u8, opt, "help") or std.mem.eql(u8, opt, "h")) {
                return .help;
            }
        } else break;
    }

    if (i >= args.len) {
        printHelp();
        return .none;
    }

    const cmd = args[i];
    i += 1;

    if (std.mem.eql(u8, cmd, "fs") or std.mem.eql(u8, cmd, "f")) {
        if (i >= args.len) {
            std.debug.print("Usage: mg fs <subcommand> [args]\n", .{});
            std.debug.print("Subcommands: create(c,touch), remove(r), copy(y), move(m), list, read, write\n", .{});
            return .none;
        }
        const fs_cmd = args[i];
        i += 1;
        const fs_args = args[i..];
        fs.handleCommand(fs_cmd, fs_args, opts.dry_run) catch {};
        return .fs;
    }

    const packages = args[i..];
    if (packages.len == 0 and (cmd[0] == 'a' or cmd[0] == 'A' or cmd[0] == 'r' or cmd[0] == 'R')) {
        std.debug.print("No packages specified\n", .{});
        return .none;
    }

    return .pkg;
}
