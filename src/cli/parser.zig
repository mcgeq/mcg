/// Command-line parser module.
///
/// This module handles all command-line argument parsing for the mg CLI.
/// It defines the parsing result types and implements the core argument
/// parsing logic.
const std = @import("std");
const fs = @import("../fs/mod.zig");
const registry = @import("../pkgm/registry.zig");
const logger = @import("../core/logger.zig");
const runtime = @import("../core/runtime.zig");
const help = @import("help.zig");

/// Result type for CLI parsing.
///
/// This enum represents the possible outcomes of parsing the command-line
/// arguments, indicating which mode the CLI should operate in.
///
/// Variants:
///   - help: User requested help information
///   - version: User requested version information
///   - fs: File system command mode
///   - pkg: Package management command mode
///   - none: No valid command was provided
pub const ParseResult = enum {
    /// User requested help information
    help,
    /// User requested version information
    version,
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

const DefaultParseDeps = struct {
    fn printHelp(_: *const @This()) void {
        help.printHelp();
    }

    fn printFsHelp(_: *const @This()) void {
        help.printFsHelp();
    }

    fn handleFsCommand(
        _: *const @This(),
        cmd: []const u8,
        args: []const [:0]const u8,
        dry_run: bool,
        cwd: ?[]const u8,
    ) !void {
        const previous_cwd = runtime.swapFsCwd(cwd);
        defer _ = runtime.swapFsCwd(previous_cwd);
        try fs.handleCommand(cmd, args, dry_run);
    }
};

const CwdOptionResult = union(enum) {
    handled: []const u8,
    not_cwd,
    missing_value: []const u8,
};

fn parseCwdOption(args: []const [:0]const u8, index: *usize) CwdOptionResult {
    const arg = args[index.*];

    if (std.mem.eql(u8, arg, "--cwd") or std.mem.eql(u8, arg, "-C")) {
        const next_index = index.* + 1;
        if (next_index >= args.len or std.mem.eql(u8, args[next_index], "--")) {
            return .{ .missing_value = arg };
        }
        index.* = next_index;
        return .{ .handled = args[next_index] };
    }

    if (std.mem.startsWith(u8, arg, "--cwd=")) {
        return .{ .handled = arg["--cwd=".len..] };
    }

    return .not_cwd;
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
pub fn parseOptions(args: []const [:0]const u8) Options {
    var opts: Options = .{};
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--dry-run") or std.mem.eql(u8, arg, "-d")) {
            opts.dry_run = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            opts.dry_run = false;
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
pub fn parse(args: []const [:0]const u8) ParseResult {
    var deps = DefaultParseDeps{};
    return parseWithDeps(&deps, args);
}

fn parseWithDeps(deps: anytype, args: []const [:0]const u8) ParseResult {
    var i: usize = 1;
    var opts: Options = .{};
    var cwd: ?[]const u8 = null;

    while (i < args.len) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--dry-run") or std.mem.eql(u8, arg, "-d")) {
            opts.dry_run = true;
            i += 1;
            continue;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            return .help;
        } else if (std.mem.eql(u8, arg, "--version")) {
            return .version;
        }

        const cwd_result = parseCwdOption(args, &i);
        switch (cwd_result) {
            .handled => |path| cwd = path,
            .missing_value => |flag| {
                logger.err("Missing path after {s}\n", .{flag});
                return .none;
            },
            .not_cwd => {},
        }
        if (cwd_result == .not_cwd) {
            break;
        }

        i += 1;
    }

    if (i >= args.len) {
        deps.printHelp();
        return .none;
    }

    const cmd = args[i];
    i += 1;

    if (std.mem.eql(u8, cmd, "version")) {
        return .version;
    }

    if (std.mem.eql(u8, cmd, "fs") or std.mem.eql(u8, cmd, "f")) {
        while (i < args.len) {
            const fs_arg = args[i];
            if (std.mem.eql(u8, fs_arg, "--dry-run") or std.mem.eql(u8, fs_arg, "-d")) {
                opts.dry_run = true;
                i += 1;
                continue;
            }
            if (std.mem.eql(u8, fs_arg, "--help") or std.mem.eql(u8, fs_arg, "-h")) {
                deps.printFsHelp();
                return .none;
            }

            const fs_cwd_result = parseCwdOption(args, &i);
            switch (fs_cwd_result) {
                .handled => |path| {
                    cwd = path;
                    i += 1;
                    continue;
                },
                .missing_value => |flag| {
                    logger.err("Missing path after {s}\n", .{flag});
                    return .none;
                },
                .not_cwd => {},
            }

            const fs_cmd = fs_arg;
            i += 1;
            const fs_args = args[i..];
            deps.handleFsCommand(fs_cmd, fs_args, opts.dry_run, cwd) catch {};
            return .fs;
        }

        deps.printFsHelp();
        return .none;
    }

    const packages = args[i..];
    if (packages.len == 0 and registry.actionRequiresPackages(cmd)) {
        logger.err("No packages specified\n", .{});
        return .none;
    }
    if (packages.len == 0 and registry.actionRequiresRunTarget(cmd)) {
        logger.err("No run target specified\n", .{});
        return .none;
    }

    return .pkg;
}

const RecordedFsDispatch = struct {
    cmd: []const u8,
    args_len: usize,
    first_arg: ?[]const u8 = null,
    dry_run: bool,
    cwd: ?[]const u8 = null,
};

const RecordingParseDeps = struct {
    help_count: usize = 0,
    fs_help_count: usize = 0,
    fs_dispatch_count: usize = 0,
    last_fs_dispatch: ?RecordedFsDispatch = null,

    fn printHelp(self: *@This()) void {
        self.help_count += 1;
    }

    fn printFsHelp(self: *@This()) void {
        self.fs_help_count += 1;
    }

    fn handleFsCommand(
        self: *@This(),
        cmd: []const u8,
        args: []const [:0]const u8,
        dry_run: bool,
        cwd: ?[]const u8,
    ) !void {
        self.fs_dispatch_count += 1;
        self.last_fs_dispatch = .{
            .cmd = cmd,
            .args_len = args.len,
            .first_arg = if (args.len > 0) args[0] else null,
            .dry_run = dry_run,
            .cwd = cwd,
        };
    }
};

fn setTestRuntime(environ_map: *std.process.Environ.Map) void {
    runtime.set(.{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = environ_map,
    });
}

fn muteLogger() logger.LogLevel {
    const log = logger.getLogger();
    const old_level = log.level;
    log.level = .off;
    return old_level;
}

test "parseWithDeps routes fs dry-run command to fs handler" {
    var deps = RecordingParseDeps{};
    const result = parseWithDeps(&deps, &.{
        "mg",
        "-d",
        "-C",
        "workspace/demo",
        "fs",
        "ls",
        "src",
    });

    try std.testing.expectEqual(ParseResult.fs, result);
    try std.testing.expectEqual(@as(usize, 1), deps.fs_dispatch_count);
    try std.testing.expectEqualStrings("ls", deps.last_fs_dispatch.?.cmd);
    try std.testing.expectEqual(@as(usize, 1), deps.last_fs_dispatch.?.args_len);
    try std.testing.expectEqualStrings("src", deps.last_fs_dispatch.?.first_arg.?);
    try std.testing.expect(deps.last_fs_dispatch.?.dry_run);
    try std.testing.expectEqualStrings("workspace/demo", deps.last_fs_dispatch.?.cwd.?);
}

test "parseWithDeps prints fs help when subcommand is missing" {
    var deps = RecordingParseDeps{};
    const result = parseWithDeps(&deps, &.{
        "mg",
        "fs",
    });

    try std.testing.expectEqual(ParseResult.none, result);
    try std.testing.expectEqual(@as(usize, 1), deps.fs_help_count);
    try std.testing.expectEqual(@as(usize, 0), deps.fs_dispatch_count);
}

test "parseWithDeps accepts cwd before fs subcommand" {
    var deps = RecordingParseDeps{};
    const result = parseWithDeps(&deps, &.{
        "mg",
        "fs",
        "--cwd=workspace/mobile",
        "list",
        "src",
    });

    try std.testing.expectEqual(ParseResult.fs, result);
    try std.testing.expectEqual(@as(usize, 1), deps.fs_dispatch_count);
    try std.testing.expectEqualStrings("list", deps.last_fs_dispatch.?.cmd);
    try std.testing.expectEqualStrings("workspace/mobile", deps.last_fs_dispatch.?.cwd.?);
    try std.testing.expectEqualStrings("src", deps.last_fs_dispatch.?.first_arg.?);
}

test "parseWithDeps prints main help when no command is provided" {
    var deps = RecordingParseDeps{};
    const result = parseWithDeps(&deps, &.{"mg"});

    try std.testing.expectEqual(ParseResult.none, result);
    try std.testing.expectEqual(@as(usize, 1), deps.help_count);
    try std.testing.expectEqual(@as(usize, 0), deps.fs_help_count);
}

test "parse returns pkg for package command with packages" {
    const result = parse(&.{
        "mg",
        "add",
        "serde",
    });

    try std.testing.expectEqual(ParseResult.pkg, result);
}

test "parse returns version for long flag" {
    const result = parse(&.{
        "mg",
        "--version",
    });

    try std.testing.expectEqual(ParseResult.version, result);
}

test "parse returns version for version command" {
    const result = parse(&.{
        "mg",
        "version",
    });

    try std.testing.expectEqual(ParseResult.version, result);
}

test "parse returns pkg for exec command with passthrough separator" {
    const result = parse(&.{
        "mg",
        "exec",
        "--",
        "run",
        "build:apk",
    });

    try std.testing.expectEqual(ParseResult.pkg, result);
}

test "parse returns pkg for run shorthand command" {
    const result = parse(&.{
        "mg",
        "run",
        "build",
    });

    try std.testing.expectEqual(ParseResult.pkg, result);
}

test "parse returns none when required package arguments are missing" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    const result = parse(&.{
        "mg",
        "add",
    });

    try std.testing.expectEqual(ParseResult.none, result);
}

test "parse returns none when run target is missing" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    const result = parse(&.{
        "mg",
        "run",
    });

    try std.testing.expectEqual(ParseResult.none, result);
}
