/// CLI help module.
///
/// This module provides help text output for the mg CLI.
const std = @import("std");
const build_options = @import("build_options");
const logger = @import("../core/logger.zig");
const runtime = @import("../core/runtime.zig");

const version_line = std.fmt.comptimePrint("mg {s}", .{build_options.mg_version});

const main_help_lines = [_][]const u8{
    "mg - Multi-package manager CLI",
    "Usage: mg [options] <command> [args]",
    "Commands: add, remove, upgrade, install, list, analyze, run, exec, version",
    "FS Commands: fs create, fs remove, fs copy, fs move, fs list, fs exists, fs read, fs write",
    "Shared Options: --cwd/-C <path>, --dry-run/-d",
    "Package Options: --dev/-D, --profile/-P <name> (repeatable), --group/-G <name> (alias), -- <manager args>",
    "General Options: --help, -h, --version",
};

const fs_help_lines = [_][]const u8{
    "Usage: mg fs <subcommand> [args]",
    "Options before subcommand: --cwd/-C <path>, --dry-run/-d",
    "Subcommands: create(c,touch), remove(r), copy(y), move(m), list(ls), exists(test), read(cat), write(echo)",
};

pub fn getMainHelpLines() []const []const u8 {
    return main_help_lines[0..];
}

pub fn getFsHelpLines() []const []const u8 {
    return fs_help_lines[0..];
}

pub fn getVersionLine() []const u8 {
    return version_line;
}

/// Prints the main help information to stdout.
///
/// Displays a summary of available commands, file system operations,
/// and command-line options for the mg CLI.
pub fn printHelp() void {
    logger.infoMulti(getMainHelpLines());
}

/// Prints the file system subcommand help.
pub fn printFsHelp() void {
    logger.infoMulti(getFsHelpLines());
}

pub fn printVersion() void {
    logger.info("{s}", .{getVersionLine()});
}

fn expectLineSlicesEqual(expected: []const []const u8, actual: []const []const u8) !void {
    try std.testing.expectEqual(expected.len, actual.len);

    for (expected, actual) |expected_line, actual_line| {
        try std.testing.expectEqualStrings(expected_line, actual_line);
    }
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

fn setTestRuntime(environ_map: *std.process.Environ.Map) void {
    runtime.set(.{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = environ_map,
    });
}

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

test "getMainHelpLines returns stable main help content" {
    try expectLineSlicesEqual(&.{
        "mg - Multi-package manager CLI",
        "Usage: mg [options] <command> [args]",
        "Commands: add, remove, upgrade, install, list, analyze, run, exec, version",
        "FS Commands: fs create, fs remove, fs copy, fs move, fs list, fs exists, fs read, fs write",
        "Shared Options: --cwd/-C <path>, --dry-run/-d",
        "Package Options: --dev/-D, --profile/-P <name> (repeatable), --group/-G <name> (alias), -- <manager args>",
        "General Options: --help, -h, --version",
    }, getMainHelpLines());
}

test "getFsHelpLines returns stable fs help content" {
    try expectLineSlicesEqual(&.{
        "Usage: mg fs <subcommand> [args]",
        "Options before subcommand: --cwd/-C <path>, --dry-run/-d",
        "Subcommands: create(c,touch), remove(r), copy(y), move(m), list(ls), exists(test), read(cat), write(echo)",
    }, getFsHelpLines());
}

test "getVersionLine returns manifest version" {
    try std.testing.expectEqualStrings(version_line, getVersionLine());
}

test "printHelp writes captured stdout" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);

    const logger_state = installPlainLogger();
    defer restoreLoggerState(logger_state);

    var capture = TestOutputCapture{};
    defer capture.deinit(std.testing.allocator);
    const previous_output = installOutputCapture(&capture);
    defer restoreOutputCapture(previous_output);

    printHelp();

    try expectCapturedInfoLines(capture.stdout.items, getMainHelpLines());
    try std.testing.expectEqual(@as(usize, 0), capture.stderr.items.len);
}

test "printFsHelp writes captured stdout" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);

    const logger_state = installPlainLogger();
    defer restoreLoggerState(logger_state);

    var capture = TestOutputCapture{};
    defer capture.deinit(std.testing.allocator);
    const previous_output = installOutputCapture(&capture);
    defer restoreOutputCapture(previous_output);

    printFsHelp();

    try expectCapturedInfoLines(capture.stdout.items, getFsHelpLines());
    try std.testing.expectEqual(@as(usize, 0), capture.stderr.items.len);
}

test "printVersion writes captured stdout" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);

    const logger_state = installPlainLogger();
    defer restoreLoggerState(logger_state);

    var capture = TestOutputCapture{};
    defer capture.deinit(std.testing.allocator);
    const previous_output = installOutputCapture(&capture);
    defer restoreOutputCapture(previous_output);

    printVersion();

    try expectCapturedInfoLines(capture.stdout.items, &.{getVersionLine()});
    try std.testing.expectEqual(@as(usize, 0), capture.stderr.items.len);
}
