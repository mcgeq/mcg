/// Command-line interface module.
///
/// This module handles all command-line argument parsing and provides
/// help text output for the mg CLI. It defines the parsing result types
/// and implements the core argument parsing logic.
const std = @import("std");
const fs = @import("fs/mod.zig");
const logger = @import("logger.zig");

/// Result type for CLI parsing.
///
/// This enum represents the possible outcomes of parsing the command-line
/// arguments, indicating which mode the CLI should operate in.
///
/// Variants:
///   - help: User requested help information
///   - fs: File system command mode
///   - pkg: Package management command mode
///   - none: No valid command was provided
pub const ParseResult = enum {
    /// User requested help or displayed version info
    help,
    /// File system operation was requested
    fs,
    /// Package management operation was requested
    pkg,
    /// No valid command (help already shown)
    none,
};

/// CLI options structure.
///
/// Holds the configuration options parsed from command-line arguments.
/// These options affect how commands are executed (e.g., dry-run mode).
///
/// Fields:
///   - dry_run: If true, commands are previewed but not executed
pub const Options = struct {
    /// Preview mode - show what would happen without executing
    dry_run: bool = false,
};

/// Prints the help information to stdout.
///
/// Displays a summary of available commands, file system operations,
/// and command-line options for the mg CLI.
pub fn printHelp() void {
    logger.infoMulti(&.{
        "mg - Multi-package manager CLI",
        "Usage: mg [options] <command> [args]",
        "Commands: add, remove, upgrade, install, analyze",
        "FS Commands: fs create, fs remove, fs copy, fs move, fs list, fs read, fs write",
        "Options: --dry-run, --help",
    });
}

/// Parses command-line options (flags starting with --).
///
/// This function extracts only the option flags from the arguments,
/// ignoring positional arguments. Options must start with "--".
///
/// Parameters:
///   - args: Slice of command-line argument strings
///
/// Returns:
///   Options struct with parsed configuration
///
/// Supported Options:
///   --dry-run, -d: Enable dry-run mode
///   --help, -h: Show help (parsed but doesn't set dry_run)
///
/// Example:
///   ```zig
///   const opts = parseOptions(&.{"--dry-run", "add", "lodash"});
///   // opts.dry_run == true
/// ```
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

/// Main CLI argument parsing function.
///
/// Parses the complete command-line argument list and determines the
/// appropriate operation mode. Handles options, commands, and subcommands.
///
/// Parameters:
///   - args: Full command-line argument slice (including program name)
///
/// Returns:
///   ParseResult indicating the operation mode
///
/// Parsing Process:
///   1. Extract and parse options (--dry-run, --help)
///   2. Identify the command (fs or package command)
///   3. For fs: parse subcommand and dispatch to fs module
///   4. For pkg: validate and return package command mode
///
/// Command Structure:
///   mg [options] [fs <subcommand> | <pkg-command> [packages]]
///
/// Example:
///   ```zig
///   const result = parse(&.{"mg", "--dry-run", "add", "lodash"});
///   // result == .pkg
///
///   const result = parse(&.{"mg", "fs", "list"});
///   // result == .fs
/// ```
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
            logger.infoMulti(&.{
                "Usage: mg fs <subcommand> [args]",
                "Subcommands: create(c,touch), remove(r), copy(y), move(m), list, read, write",
            });
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
        logger.err("No packages specified\n", .{});
        return .none;
    }

    return .pkg;
}
