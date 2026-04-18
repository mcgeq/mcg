/// Application core module for mg.
///
/// This module provides the main application logic and command dispatching.
/// It serves as the central coordinator between CLI parsing and module execution.
const std = @import("std");
const cli = @import("cli/mod.zig");
const CommandArgs = @import("core/types.zig").CommandArgs;
const PackageOptions = @import("core/types.zig").PackageOptions;
const pkgm = @import("pkgm/mod.zig");
const logger = @import("core/logger.zig");
const runtime = @import("core/runtime.zig");

/// Main application structure.
pub const App = struct {
    pub const AppContext = struct {
        allocator: std.mem.Allocator,
        io: std.Io,
        environ_map: *std.process.Environ.Map,
    };

    const DefaultAppDeps = struct {
        fn parse(_: *const @This(), args: []const [:0]const u8) cli.ParseResult {
            return cli.parser.parse(args);
        }

        fn printHelp(_: *const @This()) void {
            cli.help.printHelp();
        }

        fn printVersion(_: *const @This()) void {
            cli.help.printVersion();
        }

        fn executePackage(
            _: *const @This(),
            action: []const u8,
            command_args: *const CommandArgs,
            options: *const PackageOptions,
        ) !void {
            try pkgm.executeCommand(action, command_args, options);
        }
    };

    /// Runs the application with the given command-line arguments.
    ///
    /// Parameters:
    ///   - args: Command-line argument slice (including program name)
    ///
    /// Returns:
    ///   !void - May return errors from underlying operations
    pub fn run(ctx: *AppContext, args: []const [:0]const u8) !void {
        var deps = DefaultAppDeps{};
        try runWithDeps(&deps, ctx, args);
    }

    fn runWithDeps(deps: anytype, ctx: *AppContext, args: []const [:0]const u8) !void {
        // Parse command-line arguments
        const result = deps.parse(args);

        // Dispatch based on parse result
        switch (result) {
            .help => deps.printHelp(),
            .version => deps.printVersion(),
            .fs => {
                // FS commands are handled within the parser
                // This arm is reached when fs command completes successfully
            },
            .pkg => try handlePackageCommandWithDeps(deps, ctx, args),
            .none => {
                // No valid command or help already shown
            },
        }
    }

    /// Handles package management commands.
    fn handlePackageCommand(ctx: *AppContext, args: []const [:0]const u8) !void {
        var deps = DefaultAppDeps{};
        try handlePackageCommandWithDeps(&deps, ctx, args);
    }

    fn handlePackageCommandWithDeps(
        deps: anytype,
        ctx: *AppContext,
        args: []const [:0]const u8,
    ) !void {
        var parse_result = try parsePackageInvocation(ctx.allocator, args);
        switch (parse_result) {
            .invocation => |*parsed| {
                defer parsed.deinit();

                if (parsed.command_args.packages.items.len == 0 and
                    parsed.command_args.manager_args.items.len == 0 and
                    pkgm.registry.actionRequiresPackages(parsed.action))
                {
                    logger.err("No packages specified\n", .{});
                    return;
                }

                if (parsed.command_args.packages.items.len == 0 and
                    pkgm.registry.actionRequiresRunTarget(parsed.action))
                {
                    logger.err("No run target specified\n", .{});
                    return;
                }

                try deps.executePackage(parsed.action, &parsed.command_args, &parsed.options);
            },
            .help_requested => {
                deps.printHelp();
                return;
            },
            .none => {
                logger.err("No package command specified\n", .{});
                return;
            },
            .reported_error => return,
        }
    }

    const PackageInvocation = struct {
        action: []const u8,
        command_args: CommandArgs,
        options: PackageOptions = .{},

        fn init(allocator: std.mem.Allocator) PackageInvocation {
            return .{
                .action = "",
                .command_args = CommandArgs.init(allocator),
            };
        }

        fn deinit(self: *PackageInvocation) void {
            self.command_args.deinit();
        }
    };

    const PackageParseResult = union(enum) {
        invocation: PackageInvocation,
        help_requested,
        none,
        reported_error,
    };

    const PackageOptionResult = enum {
        handled,
        not_option,
        stop_help,
        stop_error,
    };

    fn parsePackageOption(
        parsed: *PackageInvocation,
        args: []const [:0]const u8,
        index: *usize,
    ) PackageOptionResult {
        const arg = args[index.*];

        if (std.mem.eql(u8, arg, "--dry-run") or std.mem.eql(u8, arg, "-d")) {
            parsed.options.dry_run = true;
            return .handled;
        }

        if (std.mem.eql(u8, arg, "--cwd") or std.mem.eql(u8, arg, "-C")) {
            const next_index = index.* + 1;
            if (next_index >= args.len or std.mem.eql(u8, args[next_index], "--")) {
                logger.err("Missing path after {s}\n", .{arg});
                return .stop_error;
            }
            parsed.options.cwd = args[next_index];
            index.* = next_index;
            return .handled;
        }

        if (std.mem.startsWith(u8, arg, "--cwd=")) {
            parsed.options.cwd = arg["--cwd=".len..];
            return .handled;
        }

        if (std.mem.eql(u8, arg, "--dev") or std.mem.eql(u8, arg, "-D")) {
            parsed.options.dev = true;
            return .handled;
        }

        if (std.mem.eql(u8, arg, "--group") or
            std.mem.eql(u8, arg, "-G") or
            std.mem.eql(u8, arg, "--profile") or
            std.mem.eql(u8, arg, "-P"))
        {
            const next_index = index.* + 1;
            if (next_index >= args.len or std.mem.eql(u8, args[next_index], "--")) {
                logger.err("Missing profile name after {s}\n", .{arg});
                return .stop_error;
            }
            if (!parsed.options.addProfile(args[next_index])) {
                logger.err("Too many profile names specified (max {d})\n", .{PackageOptions.max_groups});
                return .stop_error;
            }
            index.* = next_index;
            return .handled;
        }

        if (std.mem.startsWith(u8, arg, "--group=") or std.mem.startsWith(u8, arg, "--profile=")) {
            const value = if (std.mem.startsWith(u8, arg, "--group="))
                arg["--group=".len..]
            else
                arg["--profile=".len..];

            if (!parsed.options.addProfile(value)) {
                logger.err("Too many profile names specified (max {d})\n", .{PackageOptions.max_groups});
                return .stop_error;
            }
            return .handled;
        }

        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            return .stop_help;
        }

        if (std.mem.startsWith(u8, arg, "-")) {
            logger.err("Unknown package option: {s} (use -- to pass manager-native args)\n", .{arg});
            return .stop_error;
        }

        return .not_option;
    }

    fn parsePackageInvocation(allocator: std.mem.Allocator, args: []const [:0]const u8) !PackageParseResult {
        var i: usize = 1;
        var parsed = PackageInvocation.init(allocator);
        errdefer parsed.deinit();

        while (i < args.len) {
            switch (parsePackageOption(&parsed, args, &i)) {
                .handled => {},
                .not_option => {
                    parsed.action = args[i];
                    i += 1;
                    break;
                },
                .stop_help => return .help_requested,
                .stop_error => return .reported_error,
            }
            i += 1;
        }

        if (parsed.action.len == 0) return .none;

        while (i < args.len) {
            const arg = args[i];

            if (std.mem.eql(u8, arg, "--")) {
                i += 1;
                while (i < args.len) : (i += 1) {
                    try parsed.command_args.addManagerArg(args[i]);
                }
                return .{ .invocation = parsed };
            }

            switch (parsePackageOption(&parsed, args, &i)) {
                .handled => {},
                .not_option => try parsed.command_args.addPackage(arg),
                .stop_help => return .help_requested,
                .stop_error => return .reported_error,
            }

            i += 1;
        }

        return .{ .invocation = parsed };
    }
};

const RecordedExecute = struct {
    action: []const u8,
    options: PackageOptions,
    package_count: usize,
    first_package: ?[]const u8 = null,
    manager_arg_count: usize,
    first_manager_arg: ?[]const u8 = null,
};

const RecordingAppDeps = struct {
    parse_result: cli.ParseResult,
    help_count: usize = 0,
    version_count: usize = 0,
    execute_count: usize = 0,
    last_execute: ?RecordedExecute = null,

    fn parse(self: *const @This(), _: []const [:0]const u8) cli.ParseResult {
        return self.parse_result;
    }

    fn printHelp(self: *@This()) void {
        self.help_count += 1;
    }

    fn printVersion(self: *@This()) void {
        self.version_count += 1;
    }

    fn executePackage(
        self: *@This(),
        action: []const u8,
        command_args: *const CommandArgs,
        options: *const PackageOptions,
    ) !void {
        self.execute_count += 1;
        self.last_execute = .{
            .action = action,
            .options = options.*,
            .package_count = command_args.packages.items.len,
            .first_package = if (command_args.packages.items.len > 0) command_args.packages.items[0] else null,
            .manager_arg_count = command_args.manager_args.items.len,
            .first_manager_arg = if (command_args.manager_args.items.len > 0) command_args.manager_args.items[0] else null,
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

const TestOutputCapture = struct {
    stdout: std.ArrayList(u8) = .empty,
    stderr: std.ArrayList(u8) = .empty,

    fn deinit(self: *TestOutputCapture, allocator: std.mem.Allocator) void {
        self.stdout.deinit(allocator);
        self.stderr.deinit(allocator);
    }

    fn stdoutSink(self: *TestOutputCapture) runtime.OutputSink {
        return .{
            .context = self,
            .writeFn = writeStdout,
        };
    }

    fn stderrSink(self: *TestOutputCapture) runtime.OutputSink {
        return .{
            .context = self,
            .writeFn = writeStderr,
        };
    }

    fn writeStdout(context: *anyopaque, bytes: []const u8) void {
        const self: *TestOutputCapture = @ptrCast(@alignCast(context));
        self.stdout.appendSlice(std.testing.allocator, bytes) catch unreachable;
    }

    fn writeStderr(context: *anyopaque, bytes: []const u8) void {
        const self: *TestOutputCapture = @ptrCast(@alignCast(context));
        self.stderr.appendSlice(std.testing.allocator, bytes) catch unreachable;
    }
};

const OutputSinkState = struct {
    stdout: ?runtime.OutputSink,
    stderr: ?runtime.OutputSink,
};

fn installOutputCapture(capture: *TestOutputCapture) OutputSinkState {
    return .{
        .stdout = runtime.swapOutputSink(.stdout, capture.stdoutSink()),
        .stderr = runtime.swapOutputSink(.stderr, capture.stderrSink()),
    };
}

fn restoreOutputCapture(state: OutputSinkState) void {
    _ = runtime.swapOutputSink(.stdout, state.stdout);
    _ = runtime.swapOutputSink(.stderr, state.stderr);
}

fn expectInvocation(result: App.PackageParseResult) !App.PackageInvocation {
    return switch (result) {
        .invocation => |parsed| parsed,
        else => error.TestUnexpectedResult,
    };
}

fn expectParseNone(result: App.PackageParseResult) !void {
    switch (result) {
        .none => return,
        else => return error.TestUnexpectedResult,
    }
}

fn expectParseHelpRequested(result: App.PackageParseResult) !void {
    switch (result) {
        .help_requested => return,
        else => return error.TestUnexpectedResult,
    }
}

fn expectParseReportedError(result: App.PackageParseResult) !void {
    switch (result) {
        .reported_error => return,
        else => return error.TestUnexpectedResult,
    }
}

test "parse package invocation supports dev group and passthrough" {
    var parsed = try expectInvocation(try App.parsePackageInvocation(std.testing.allocator, &.{
        "mg",
        "-d",
        "--cwd",
        "workspace/demo",
        "add",
        "--dev",
        "--group",
        "docs",
        "mkdocs",
        "--",
        "--frozen",
    }));
    defer parsed.deinit();

    try std.testing.expectEqualStrings("add", parsed.action);
    try std.testing.expect(parsed.options.dry_run);
    try std.testing.expect(parsed.options.dev);
    try std.testing.expectEqualStrings("workspace/demo", parsed.options.cwd.?);
    try std.testing.expectEqualStrings("docs", parsed.options.group.?);
    try std.testing.expectEqual(@as(usize, 1), parsed.options.groupCount());
    try std.testing.expectEqual(@as(usize, 1), parsed.command_args.packages.items.len);
    try std.testing.expectEqualStrings("mkdocs", parsed.command_args.packages.items[0]);
    try std.testing.expectEqual(@as(usize, 1), parsed.command_args.manager_args.items.len);
    try std.testing.expectEqualStrings("--frozen", parsed.command_args.manager_args.items[0]);
}

test "parse package invocation rejects unknown option before passthrough separator" {
    try expectParseReportedError(try App.parsePackageInvocation(std.testing.allocator, &.{
        "mg",
        "add",
        "--frozen",
    }));
}

test "parse package invocation supports dev and group before action" {
    var parsed = try expectInvocation(try App.parsePackageInvocation(std.testing.allocator, &.{
        "mg",
        "--dev",
        "--group=docs",
        "add",
        "mkdocs",
    }));
    defer parsed.deinit();

    try std.testing.expectEqualStrings("add", parsed.action);
    try std.testing.expect(parsed.options.dev);
    try std.testing.expectEqualStrings("docs", parsed.options.group.?);
    try std.testing.expectEqual(@as(usize, 1), parsed.options.groupCount());
    try std.testing.expectEqual(@as(usize, 1), parsed.command_args.packages.items.len);
    try std.testing.expectEqualStrings("mkdocs", parsed.command_args.packages.items[0]);
}

test "parse package invocation keeps repeated group flags in order" {
    var parsed = try expectInvocation(try App.parsePackageInvocation(std.testing.allocator, &.{
        "mg",
        "install",
        "--group",
        "docs",
        "--group=test",
        "--group",
        "lint",
    }));
    defer parsed.deinit();

    try std.testing.expectEqualStrings("install", parsed.action);
    try std.testing.expectEqual(@as(usize, 3), parsed.options.groupCount());
    try std.testing.expectEqualStrings("docs", parsed.options.groupAt(0).?);
    try std.testing.expectEqualStrings("test", parsed.options.groupAt(1).?);
    try std.testing.expectEqualStrings("lint", parsed.options.groupAt(2).?);
    try std.testing.expectEqualStrings("lint", parsed.options.lastGroup().?);
}

test "parse package invocation accepts profile alias and keeps order with groups" {
    var parsed = try expectInvocation(try App.parsePackageInvocation(std.testing.allocator, &.{
        "mg",
        "--profile",
        "dev",
        "install",
        "-P",
        "docs",
        "--group=lint",
    }));
    defer parsed.deinit();

    try std.testing.expectEqualStrings("install", parsed.action);
    try std.testing.expectEqual(@as(usize, 3), parsed.options.profileCount());
    try std.testing.expectEqualStrings("dev", parsed.options.profileAt(0).?);
    try std.testing.expectEqualStrings("docs", parsed.options.profileAt(1).?);
    try std.testing.expectEqualStrings("lint", parsed.options.profileAt(2).?);
    try std.testing.expectEqualStrings("lint", parsed.options.lastExplicitProfile().?);
}

test "parse package invocation rejects unknown option before action" {
    try expectParseReportedError(try App.parsePackageInvocation(std.testing.allocator, &.{
        "mg",
        "--frozen",
        "add",
        "ruff",
    }));
}

test "parse package invocation returns none when only options are provided" {
    try expectParseNone(try App.parsePackageInvocation(std.testing.allocator, &.{
        "mg",
        "--dev",
        "--group",
        "docs",
    }));
}

test "parse package invocation returns help when help flag appears after action" {
    try expectParseHelpRequested(try App.parsePackageInvocation(std.testing.allocator, &.{
        "mg",
        "--dev",
        "add",
        "-h",
    }));
}

test "parse package invocation routes exec passthrough to manager args" {
    var parsed = try expectInvocation(try App.parsePackageInvocation(std.testing.allocator, &.{
        "mg",
        "--cwd=workspace/mobile",
        "exec",
        "--",
        "run",
        "build:apk",
    }));
    defer parsed.deinit();

    try std.testing.expectEqualStrings("exec", parsed.action);
    try std.testing.expectEqualStrings("workspace/mobile", parsed.options.cwd.?);
    try std.testing.expectEqual(@as(usize, 0), parsed.command_args.packages.items.len);
    try std.testing.expectEqual(@as(usize, 2), parsed.command_args.manager_args.items.len);
    try std.testing.expectEqualStrings("run", parsed.command_args.manager_args.items[0]);
    try std.testing.expectEqualStrings("build:apk", parsed.command_args.manager_args.items[1]);
}

test "parse package invocation keeps run target in positional args" {
    var parsed = try expectInvocation(try App.parsePackageInvocation(std.testing.allocator, &.{
        "mg",
        "run",
        "build",
        "--",
        "--watch",
    }));
    defer parsed.deinit();

    try std.testing.expectEqualStrings("run", parsed.action);
    try std.testing.expectEqual(@as(usize, 1), parsed.command_args.packages.items.len);
    try std.testing.expectEqualStrings("build", parsed.command_args.packages.items[0]);
    try std.testing.expectEqual(@as(usize, 1), parsed.command_args.manager_args.items.len);
    try std.testing.expectEqualStrings("--watch", parsed.command_args.manager_args.items[0]);
}

test "runWithDeps forwards package command to executor with parsed options" {
    var deps: RecordingAppDeps = .{
        .parse_result = .pkg,
    };
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    var ctx: App.AppContext = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    try App.runWithDeps(&deps, &ctx, &.{
        "mg",
        "-d",
        "--cwd",
        "workspace/api",
        "add",
        "--dev",
        "--group=docs",
        "ruff",
        "--",
        "--frozen",
    });

    try std.testing.expectEqual(@as(usize, 1), deps.execute_count);
    try std.testing.expectEqualStrings("add", deps.last_execute.?.action);
    try std.testing.expect(deps.last_execute.?.options.dry_run);
    try std.testing.expect(deps.last_execute.?.options.dev);
    try std.testing.expectEqualStrings("workspace/api", deps.last_execute.?.options.cwd.?);
    try std.testing.expectEqualStrings("docs", deps.last_execute.?.options.group.?);
    try std.testing.expectEqual(@as(usize, 1), deps.last_execute.?.options.groupCount());
    try std.testing.expectEqual(@as(usize, 1), deps.last_execute.?.package_count);
    try std.testing.expectEqualStrings("ruff", deps.last_execute.?.first_package.?);
    try std.testing.expectEqual(@as(usize, 1), deps.last_execute.?.manager_arg_count);
    try std.testing.expectEqualStrings("--frozen", deps.last_execute.?.first_manager_arg.?);
}

test "runWithDeps forwards package options placed before action" {
    var deps: RecordingAppDeps = .{
        .parse_result = .pkg,
    };
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    var ctx: App.AppContext = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    try App.runWithDeps(&deps, &ctx, &.{
        "mg",
        "--dev",
        "--group",
        "docs",
        "--cwd=workspace/api",
        "add",
        "ruff",
        "--",
        "--frozen",
    });

    try std.testing.expectEqual(@as(usize, 1), deps.execute_count);
    try std.testing.expectEqualStrings("add", deps.last_execute.?.action);
    try std.testing.expect(deps.last_execute.?.options.dev);
    try std.testing.expectEqualStrings("docs", deps.last_execute.?.options.group.?);
    try std.testing.expectEqual(@as(usize, 1), deps.last_execute.?.options.groupCount());
    try std.testing.expectEqualStrings("workspace/api", deps.last_execute.?.options.cwd.?);
    try std.testing.expectEqualStrings("ruff", deps.last_execute.?.first_package.?);
    try std.testing.expectEqualStrings("--frozen", deps.last_execute.?.first_manager_arg.?);
}

test "runWithDeps forwards profile alias before action" {
    var deps: RecordingAppDeps = .{
        .parse_result = .pkg,
    };
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    var ctx: App.AppContext = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    try App.runWithDeps(&deps, &ctx, &.{
        "mg",
        "--profile=docs",
        "-P",
        "lint",
        "install",
    });

    try std.testing.expectEqual(@as(usize, 1), deps.execute_count);
    try std.testing.expectEqualStrings("install", deps.last_execute.?.action);
    try std.testing.expectEqual(@as(usize, 2), deps.last_execute.?.options.profileCount());
    try std.testing.expectEqualStrings("docs", deps.last_execute.?.options.profileAt(0).?);
    try std.testing.expectEqualStrings("lint", deps.last_execute.?.options.profileAt(1).?);
}

test "runWithDeps does not execute package flow when parser routes fs" {
    var deps: RecordingAppDeps = .{
        .parse_result = .fs,
    };
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    var ctx: App.AppContext = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    try App.runWithDeps(&deps, &ctx, &.{
        "mg",
        "fs",
        "list",
    });

    try std.testing.expectEqual(@as(usize, 0), deps.execute_count);
}

test "runWithDeps prints help and skips execution when parser requests help" {
    var deps: RecordingAppDeps = .{
        .parse_result = .help,
    };
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    var ctx: App.AppContext = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    try App.runWithDeps(&deps, &ctx, &.{
        "mg",
        "-h",
    });

    try std.testing.expectEqual(@as(usize, 1), deps.help_count);
    try std.testing.expectEqual(@as(usize, 0), deps.execute_count);
}

test "runWithDeps prints version and skips execution when parser requests version" {
    var deps: RecordingAppDeps = .{
        .parse_result = .version,
    };
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    var ctx: App.AppContext = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    try App.runWithDeps(&deps, &ctx, &.{
        "mg",
        "--version",
    });

    try std.testing.expectEqual(@as(usize, 1), deps.version_count);
    try std.testing.expectEqual(@as(usize, 0), deps.execute_count);
}

test "runWithDeps prints help for package help flag after action" {
    var deps: RecordingAppDeps = .{
        .parse_result = .pkg,
    };
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    var ctx: App.AppContext = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    try App.runWithDeps(&deps, &ctx, &.{
        "mg",
        "--dev",
        "add",
        "--help",
    });

    try std.testing.expectEqual(@as(usize, 1), deps.help_count);
    try std.testing.expectEqual(@as(usize, 0), deps.execute_count);
}

test "runWithDeps rejects add without packages before executor" {
    var deps: RecordingAppDeps = .{
        .parse_result = .pkg,
    };
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var ctx: App.AppContext = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    try App.runWithDeps(&deps, &ctx, &.{
        "mg",
        "add",
    });

    try std.testing.expectEqual(@as(usize, 0), deps.execute_count);
}

test "runWithDeps allows install without positional packages" {
    var deps: RecordingAppDeps = .{
        .parse_result = .pkg,
    };
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    var ctx: App.AppContext = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    try App.runWithDeps(&deps, &ctx, &.{
        "mg",
        "install",
        "--",
        "--frozen",
    });

    try std.testing.expectEqual(@as(usize, 1), deps.execute_count);
    try std.testing.expectEqualStrings("install", deps.last_execute.?.action);
    try std.testing.expectEqual(@as(usize, 0), deps.last_execute.?.package_count);
    try std.testing.expectEqual(@as(usize, 1), deps.last_execute.?.manager_arg_count);
    try std.testing.expectEqualStrings("--frozen", deps.last_execute.?.first_manager_arg.?);
}

test "runWithDeps rejects run without target before executor" {
    var deps: RecordingAppDeps = .{
        .parse_result = .pkg,
    };
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var ctx: App.AppContext = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    try App.runWithDeps(&deps, &ctx, &.{
        "mg",
        "run",
    });

    try std.testing.expectEqual(@as(usize, 0), deps.execute_count);
}

test "runWithDeps rejects add without packages and writes captured stderr" {
    var deps: RecordingAppDeps = .{
        .parse_result = .pkg,
    };
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);

    const log = logger.getLogger();
    const old_level = log.level;
    const old_ansi = log.enable_ansi;
    defer {
        logger.getLogger().level = old_level;
        logger.getLogger().enable_ansi = old_ansi;
    }
    log.level = .info;
    log.enable_ansi = false;

    var capture = TestOutputCapture{};
    defer capture.deinit(std.testing.allocator);
    const previous_output = installOutputCapture(&capture);
    defer restoreOutputCapture(previous_output);

    var ctx: App.AppContext = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    try App.runWithDeps(&deps, &ctx, &.{
        "mg",
        "add",
    });

    try std.testing.expectEqualStrings(
        "[ERROR]\n    No packages specified\n",
        capture.stderr.items,
    );
    try std.testing.expectEqual(@as(usize, 0), capture.stdout.items.len);
    try std.testing.expectEqual(@as(usize, 0), deps.execute_count);
}

test "runWithDeps rejects run without target and writes captured stderr" {
    var deps: RecordingAppDeps = .{
        .parse_result = .pkg,
    };
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);

    const log = logger.getLogger();
    const old_level = log.level;
    const old_ansi = log.enable_ansi;
    defer {
        logger.getLogger().level = old_level;
        logger.getLogger().enable_ansi = old_ansi;
    }
    log.level = .info;
    log.enable_ansi = false;

    var capture = TestOutputCapture{};
    defer capture.deinit(std.testing.allocator);
    const previous_output = installOutputCapture(&capture);
    defer restoreOutputCapture(previous_output);

    var ctx: App.AppContext = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    try App.runWithDeps(&deps, &ctx, &.{
        "mg",
        "run",
    });

    try std.testing.expectEqualStrings(
        "[ERROR]\n    No run target specified\n",
        capture.stderr.items,
    );
    try std.testing.expectEqual(@as(usize, 0), capture.stdout.items.len);
    try std.testing.expectEqual(@as(usize, 0), deps.execute_count);
}

test "runWithDeps forwards exec action to package executor" {
    var deps: RecordingAppDeps = .{
        .parse_result = .pkg,
    };
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    var ctx: App.AppContext = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    try App.runWithDeps(&deps, &ctx, &.{
        "mg",
        "--cwd",
        "workspace/mobile",
        "exec",
        "--",
        "run",
        "build:apk",
    });

    try std.testing.expectEqual(@as(usize, 1), deps.execute_count);
    try std.testing.expectEqualStrings("exec", deps.last_execute.?.action);
    try std.testing.expectEqualStrings("workspace/mobile", deps.last_execute.?.options.cwd.?);
    try std.testing.expectEqual(@as(usize, 0), deps.last_execute.?.package_count);
    try std.testing.expectEqual(@as(usize, 2), deps.last_execute.?.manager_arg_count);
    try std.testing.expectEqualStrings("run", deps.last_execute.?.first_manager_arg.?);
}

test "runWithDeps forwards run action shorthand to package executor" {
    var deps: RecordingAppDeps = .{
        .parse_result = .pkg,
    };
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    var ctx: App.AppContext = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    try App.runWithDeps(&deps, &ctx, &.{
        "mg",
        "--cwd",
        "workspace/mobile",
        "run",
        "build",
        "--",
        "--watch",
    });

    try std.testing.expectEqual(@as(usize, 1), deps.execute_count);
    try std.testing.expectEqualStrings("run", deps.last_execute.?.action);
    try std.testing.expectEqualStrings("workspace/mobile", deps.last_execute.?.options.cwd.?);
    try std.testing.expectEqual(@as(usize, 1), deps.last_execute.?.package_count);
    try std.testing.expectEqualStrings("build", deps.last_execute.?.first_package.?);
    try std.testing.expectEqual(@as(usize, 1), deps.last_execute.?.manager_arg_count);
    try std.testing.expectEqualStrings("--watch", deps.last_execute.?.first_manager_arg.?);
}

test "parse package invocation allows manager args without positional package" {
    var parsed = try expectInvocation(try App.parsePackageInvocation(std.testing.allocator, &.{
        "mg",
        "add",
        "--",
        "--path",
        "../local-crate",
    }));
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 0), parsed.command_args.packages.items.len);
    try std.testing.expectEqual(@as(usize, 2), parsed.command_args.manager_args.items.len);
    try std.testing.expectEqualStrings("--path", parsed.command_args.manager_args.items[0]);
    try std.testing.expectEqualStrings("../local-crate", parsed.command_args.manager_args.items[1]);
}

test "parse package invocation supports cwd after action" {
    var parsed = try expectInvocation(try App.parsePackageInvocation(std.testing.allocator, &.{
        "mg",
        "add",
        "--cwd=workspace/tools",
        "ruff",
    }));
    defer parsed.deinit();

    try std.testing.expectEqualStrings("add", parsed.action);
    try std.testing.expectEqualStrings("workspace/tools", parsed.options.cwd.?);
    try std.testing.expectEqual(@as(usize, 1), parsed.command_args.packages.items.len);
    try std.testing.expectEqualStrings("ruff", parsed.command_args.packages.items[0]);
}

test "parse package invocation supports short cwd option" {
    var parsed = try expectInvocation(try App.parsePackageInvocation(std.testing.allocator, &.{
        "mg",
        "-C",
        "workspace/api",
        "install",
    }));
    defer parsed.deinit();

    try std.testing.expectEqualStrings("install", parsed.action);
    try std.testing.expectEqualStrings("workspace/api", parsed.options.cwd.?);
}

test "parse package invocation rejects missing cwd path" {
    try expectParseReportedError(try App.parsePackageInvocation(std.testing.allocator, &.{
        "mg",
        "add",
        "--cwd",
    }));
}
