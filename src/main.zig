/// mg - Multi-Package Manager CLI
///
/// A cross-ecosystem package management tool written in Zig without third-party
/// dependencies. Supports Cargo, npm, pnpm, yarn, bun, pip, uv, PDM, and Poetry.
///
/// Usage:
///   mg add <package>       - Add a package
///   mg remove <package>    - Remove a package
///   mg upgrade             - Upgrade all packages
///   mg run <target>        - Run a script or command on managers that expose a native run subcommand
///   mg exec -- <args...>   - Forward a native subcommand to the detected manager
///   mg version             - Show the mg version
///   mg fs <subcommand>     - File system operations
///   mg fs exists <path>    - Check whether a path exists
///
/// Options:
///   --cwd, -C <path>      - Detect and run package commands in the given directory
///   --dry-run, -d         - Preview command without executing
///   --dev, -D             - Use dev dependency mode when supported
///   --profile, -P <name>  - Target a dependency profile when supported
///   --group, -G <name>    - Backward-compatible alias of --profile
///   --                    - Pass remaining args to the underlying manager
///   --help, -h            - Show this help message
///   --version             - Show the mg version
const std = @import("std");
const App = @import("app.zig").App;
const help = @import("cli/help.zig");
const logger = @import("core/logger.zig");
const runtime = @import("core/runtime.zig");

fn isUserFacingHandledError(err: anyerror) bool {
    return switch (err) {
        error.NoPackageManager,
        error.UnsupportedManager,
        error.CommandFailed,
        error.ManagerNotInstalled,
        error.ConfigParseFailed,
        error.ConfigReadFailed,
        error.InvalidPackageName,
        error.CurrentDirFailed,
        error.IoError,
        error.CreateDirFailed,
        error.CreateFileFailed,
        error.RemoveFailed,
        error.CopyFailed,
        error.MoveFailed,
        error.PathNotFound,
        error.LoggerInitFailed,
        error.CacheCorrupted,
        error.UnknownSubcommand,
        error.MissingSubcommand,
        error.UnknownOption,
        error.InvalidArgument,
        => true,
        else => false,
    };
}

fn collectArgs(allocator: std.mem.Allocator, args_data: std.process.Args) ![][:0]u8 {
    var args_iter = try std.process.Args.Iterator.initAllocator(args_data, allocator);
    defer args_iter.deinit();

    var args: std.ArrayList([:0]u8) = .empty;
    errdefer {
        for (args.items) |arg| allocator.free(arg);
        args.deinit(allocator);
    }

    while (args_iter.next()) |arg| {
        try args.append(allocator, try allocator.dupeZ(u8, arg));
    }

    return try args.toOwnedSlice(allocator);
}

fn freeArgs(allocator: std.mem.Allocator, args: []const [:0]const u8) void {
    for (args) |arg| allocator.free(arg);
    allocator.free(args);
}

fn runArgs(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *std.process.Environ.Map,
    args: []const [:0]const u8,
) !void {
    const stdout_sink = if (runtime.isInitialized()) runtime.get().stdout_sink else null;
    const stderr_sink = if (runtime.isInitialized()) runtime.get().stderr_sink else null;

    runtime.set(.{
        .allocator = allocator,
        .io = io,
        .environ_map = environ_map,
        .stdout_sink = stdout_sink,
        .stderr_sink = stderr_sink,
    });

    if (args.len < 2) {
        help.printHelp();
        return;
    }

    var ctx: App.AppContext = .{
        .allocator = allocator,
        .io = io,
        .environ_map = environ_map,
    };

    try App.run(&ctx, args);
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try collectArgs(allocator, init.minimal.args);
    defer freeArgs(allocator, args);

    runArgs(allocator, init.io, init.environ_map, args) catch |err| {
        if (isUserFacingHandledError(err)) {
            std.process.exit(1);
        }
        return err;
    };
}

test "isUserFacingHandledError matches mg surface errors" {
    try std.testing.expect(isUserFacingHandledError(error.CommandFailed));
    try std.testing.expect(isUserFacingHandledError(error.NoPackageManager));
    try std.testing.expect(isUserFacingHandledError(error.UnknownOption));
    try std.testing.expect(!isUserFacingHandledError(error.OutOfMemory));
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

const LoggerState = struct {
    level: logger.LogLevel,
    enable_ansi: bool,
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

fn installPlainLogger() LoggerState {
    const log = logger.getLogger();
    const state: LoggerState = .{
        .level = log.level,
        .enable_ansi = log.enable_ansi,
    };
    log.level = .info;
    log.enable_ansi = false;
    return state;
}

fn restoreLoggerState(state: LoggerState) void {
    const log = logger.getLogger();
    log.level = state.level;
    log.enable_ansi = state.enable_ansi;
}

fn expectCapturedInfoLines(actual: []const u8, lines: []const []const u8) !void {
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(std.testing.allocator);

    try expected.appendSlice(std.testing.allocator, "[INFO]\n");
    for (lines) |line| {
        try expected.appendSlice(std.testing.allocator, "    ");
        try expected.appendSlice(std.testing.allocator, line);
        try expected.append(std.testing.allocator, '\n');
    }

    try std.testing.expectEqualStrings(expected.items, actual);
}

test "runArgs prints help when no command is provided" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    const args = [_][:0]u8{@constCast("mg")};

    const logger_state = installPlainLogger();
    defer restoreLoggerState(logger_state);

    runtime.set(.{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    });

    var capture = TestOutputCapture{};
    defer capture.deinit(std.testing.allocator);
    const previous_output = installOutputCapture(&capture);
    defer restoreOutputCapture(previous_output);

    try runArgs(std.testing.allocator, std.testing.io, &environ_map, &args);

    try expectCapturedInfoLines(capture.stdout.items, help.getMainHelpLines());
    try std.testing.expectEqual(@as(usize, 0), capture.stderr.items.len);
}
