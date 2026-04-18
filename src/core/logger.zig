const std = @import("std");
const runtime = @import("runtime.zig");

pub const LogLevel = enum(u8) {
    trace = 0,
    debug = 1,
    info = 2,
    warn = 3,
    @"error" = 4,
    off = 5,
};

const ansi_colors = struct {
    const reset = "\x1b[0m";
    const trace = "\x1b[90m";
    const debug = "\x1b[36m";
    const info = "\x1b[32m";
    const warn = "\x1b[33m";
    const err = "\x1b[31m";
};

pub const Logger = struct {
    level: LogLevel,
    enable_ansi: bool,

    pub fn init(level: LogLevel) Logger {
        return Logger{
            .level = level,
            .enable_ansi = true,
        };
    }

    fn shouldLog(self: *Logger, level: LogLevel) bool {
        return @intFromEnum(level) >= @intFromEnum(self.level) and self.level != .off;
    }

    fn getColor(level: LogLevel) []const u8 {
        return switch (level) {
            .trace => ansi_colors.trace,
            .debug => ansi_colors.debug,
            .info => ansi_colors.info,
            .warn => ansi_colors.warn,
            .@"error" => ansi_colors.err,
            else => "",
        };
    }

    fn getLevelName(level: LogLevel) []const u8 {
        return switch (level) {
            .trace => "TRACE",
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .@"error" => "ERROR",
            else => "",
        };
    }

    fn trimTrailingNewline(message: []const u8) []const u8 {
        return if (message.len > 0 and message[message.len - 1] == '\n')
            message[0 .. message.len - 1]
        else
            message;
    }

    fn formatLogLine(
        buf: []u8,
        level: LogLevel,
        enable_ansi: bool,
        message: []const u8,
    ) ![]const u8 {
        const level_name = getLevelName(level);
        const color = if (enable_ansi) getColor(level) else "";
        const reset = if (enable_ansi) ansi_colors.reset else "";
        const msg_trimmed = trimTrailingNewline(message);

        const rendered = try std.fmt.bufPrint(
            buf,
            "{s}[{s}]{s}\n    {s}\n",
            .{ color, level_name, reset, msg_trimmed },
        );
        return rendered;
    }

    fn formatInfoMulti(
        buf: []u8,
        enable_ansi: bool,
        messages: []const []const u8,
    ) ![]const u8 {
        const color = if (enable_ansi) ansi_colors.info else "";
        const reset = if (enable_ansi) ansi_colors.reset else "";

        var stream = std.Io.Writer.fixed(buf);
        try stream.print("{s}[INFO]{s}\n", .{ color, reset });
        for (messages) |msg| {
            try stream.print("    {s}\n", .{trimTrailingNewline(msg)});
        }

        return stream.buffered();
    }

    pub fn log(self: *Logger, level: LogLevel, message: []const u8) void {
        if (!self.shouldLog(level)) return;

        var buf: [2048]u8 = undefined;
        const rendered = formatLogLine(&buf, level, self.enable_ansi, message) catch return;
        switch (level) {
            .@"error", .warn => runtime.writeStderr(rendered),
            else => runtime.writeStdout(rendered),
        }
    }

    pub fn trace(self: *Logger, message: []const u8) void {
        self.log(.trace, message);
    }

    pub fn debug(self: *Logger, message: []const u8) void {
        self.log(.debug, message);
    }

    pub fn info(self: *Logger, message: []const u8) void {
        self.log(.info, message);
    }

    pub fn warn(self: *Logger, message: []const u8) void {
        self.log(.warn, message);
    }

    pub fn logError(self: *Logger, message: []const u8) void {
        self.log(.@"error", message);
    }

    pub fn logFmt(self: *Logger, level: LogLevel, comptime format: []const u8, args: anytype) void {
        if (!self.shouldLog(level)) return;

        var msg_buf: [1024]u8 = undefined;
        const message = std.fmt.bufPrint(&msg_buf, format, args) catch return;
        self.log(level, message);
    }

    pub fn traceFmt(self: *Logger, comptime format: []const u8, args: anytype) void {
        self.logFmt(.trace, format, args);
    }

    pub fn debugFmt(self: *Logger, comptime format: []const u8, args: anytype) void {
        self.logFmt(.debug, format, args);
    }

    pub fn infoFmt(self: *Logger, comptime format: []const u8, args: anytype) void {
        self.logFmt(.info, format, args);
    }

    pub fn infoMulti(self: *Logger, messages: []const []const u8) void {
        if (!self.shouldLog(.info)) return;

        var buf: [4096]u8 = undefined;
        const rendered = formatInfoMulti(&buf, self.enable_ansi, messages) catch {
            // 消息太长，回退到多次写入
            const color = if (self.enable_ansi) ansi_colors.info else "";
            const reset = if (self.enable_ansi) ansi_colors.reset else "";
            runtime.writeStdout(color);
            runtime.writeStdout("[INFO]");
            runtime.writeStdout(reset);
            runtime.writeStdout("\n");

            for (messages) |msg| {
                var line_buf: [1024]u8 = undefined;
                const line = std.fmt.bufPrint(&line_buf, "    {s}\n", .{msg}) catch continue;
                runtime.writeStdout(line);
            }
            return;
        };
        runtime.writeStdout(rendered);
    }

    pub fn warnFmt(self: *Logger, comptime format: []const u8, args: anytype) void {
        self.logFmt(.warn, format, args);
    }

    pub fn errorFmt(self: *Logger, comptime format: []const u8, args: anytype) void {
        self.logFmt(.@"error", format, args);
    }
};

var global_logger: ?Logger = null;

pub fn getLogger() *Logger {
    if (global_logger == null) {
        global_logger = Logger.init(.info);
    }
    return &global_logger.?;
}

pub inline fn err(comptime fmt: []const u8, args: anytype) void {
    getLogger().errorFmt(fmt, args);
}

pub inline fn warn(comptime fmt: []const u8, args: anytype) void {
    getLogger().warnFmt(fmt, args);
}

pub inline fn info(comptime fmt: []const u8, args: anytype) void {
    getLogger().infoFmt(fmt, args);
}

pub inline fn infoMulti(messages: []const []const u8) void {
    getLogger().infoMulti(messages);
}

pub inline fn debug(comptime fmt: []const u8, args: anytype) void {
    getLogger().debugFmt(fmt, args);
}

pub inline fn trace(comptime fmt: []const u8, args: anytype) void {
    getLogger().traceFmt(fmt, args);
}

pub fn flushLogger() void {}

pub fn parseLogLevel(level_str: []const u8) LogLevel {
    var lower_buf: [16]u8 = undefined;
    const lower = std.ascii.lowerString(&lower_buf, level_str);
    if (std.mem.eql(u8, lower, "trace")) return .trace;
    if (std.mem.eql(u8, lower, "debug")) return .debug;
    if (std.mem.eql(u8, lower, "info")) return .info;
    if (std.mem.eql(u8, lower, "warn")) return .warn;
    if (std.mem.eql(u8, lower, "error")) return .@"error";
    if (std.mem.eql(u8, lower, "off")) return .off;
    return .info;
}

test "Logger.formatLogLine renders plain info message" {
    var buf: [256]u8 = undefined;
    const rendered = try Logger.formatLogLine(&buf, .info, false, "done");
    try std.testing.expectEqualStrings("[INFO]\n    done\n", rendered);
}

test "Logger.formatLogLine trims trailing newline and keeps ansi" {
    var buf: [256]u8 = undefined;
    const rendered = try Logger.formatLogLine(&buf, .@"error", true, "boom\n");
    try std.testing.expectEqualStrings("\x1b[31m[ERROR]\x1b[0m\n    boom\n", rendered);
}

test "Logger.formatInfoMulti renders multiple plain lines" {
    var buf: [256]u8 = undefined;
    const rendered = try Logger.formatInfoMulti(&buf, false, &.{ "alpha", "beta" });
    try std.testing.expectEqualStrings("[INFO]\n    alpha\n    beta\n", rendered);
}

test "Logger.formatInfoMulti trims per-line trailing newlines" {
    var buf: [256]u8 = undefined;
    const rendered = try Logger.formatInfoMulti(&buf, true, &.{ "alpha\n", "beta\n" });
    try std.testing.expectEqualStrings("\x1b[32m[INFO]\x1b[0m\n    alpha\n    beta\n", rendered);
}

test "parseLogLevel accepts common values case-insensitively" {
    try std.testing.expectEqual(.trace, parseLogLevel("TRACE"));
    try std.testing.expectEqual(.debug, parseLogLevel("debug"));
    try std.testing.expectEqual(.info, parseLogLevel("Info"));
    try std.testing.expectEqual(.warn, parseLogLevel("warn"));
    try std.testing.expectEqual(.@"error", parseLogLevel("ERROR"));
    try std.testing.expectEqual(.off, parseLogLevel("off"));
    try std.testing.expectEqual(.info, parseLogLevel("unknown"));
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

fn setTestRuntime(environ_map: *std.process.Environ.Map) void {
    runtime.set(.{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = environ_map,
    });
}

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

test "Logger.log writes info output through runtime stdout sink" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);

    var capture = TestOutputCapture{};
    defer capture.deinit(std.testing.allocator);
    const previous = installOutputCapture(&capture);
    defer restoreOutputCapture(previous);

    var log = Logger.init(.info);
    log.enable_ansi = false;
    log.log(.info, "captured");

    try std.testing.expectEqualStrings("[INFO]\n    captured\n", capture.stdout.items);
    try std.testing.expectEqual(@as(usize, 0), capture.stderr.items.len);
}

test "Logger.log writes warning output through runtime stderr sink" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);

    var capture = TestOutputCapture{};
    defer capture.deinit(std.testing.allocator);
    const previous = installOutputCapture(&capture);
    defer restoreOutputCapture(previous);

    var log = Logger.init(.info);
    log.enable_ansi = false;
    log.log(.warn, "careful");

    try std.testing.expectEqualStrings("[WARN]\n    careful\n", capture.stderr.items);
    try std.testing.expectEqual(@as(usize, 0), capture.stdout.items.len);
}
