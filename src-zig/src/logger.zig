const std = @import("std");
const MgError = @import("error.zig").MgError;

pub const LogLevel = enum(u8) {
    trace = 0,
    debug = 1,
    info = 2,
    warn = 3,
    @"error" = 4,
    off = 5,
};

pub const Logger = struct {
    level: LogLevel,
    writer: std.fs.File.Writer,
    enable_ansi: bool,

    pub fn init(level: LogLevel, writer: std.fs.File.Writer) Logger {
        return Logger{
            .level = level,
            .writer = writer,
            .enable_ansi = supportsAnsiEscapeCodes(),
        };
    }

    pub fn deinit(self: *Logger) void {
        _ = self;
    }

    fn shouldLog(self: *Logger, level: LogLevel) bool {
        return @intFromEnum(level) >= @intFromEnum(self.level) and self.level != .off;
    }

    pub fn log(self: *Logger, level: LogLevel, message: []const u8) void {
        if (!self.shouldLog(level)) return;

        const timestamp = std.time.timestamp();
        const level_name = @tagName(level);

        if (self.enable_ansi) {
            const reset = "\x1b[0m";
            const color = switch (level) {
                .trace => "\x1b[90m",
                .debug => "\x1b[36m",
                .info => "\x1b[32m",
                .warn => "\x1b[33m",
                .@"error" => "\x1b[31m",
                else => "",
            };
            self.writer.print("[{d}] {s}{s}{s} {s}\n", .{ timestamp, color, level_name, reset, message }) catch {};
        } else {
            self.writer.print("[{d}] {s} {s}\n", .{ timestamp, level_name, message }) catch {};
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

        const timestamp = std.time.timestamp();
        const level_name = @tagName(level);
        var buf: [4096]u8 = undefined;
        const message = std.fmt.bufPrint(&buf, format, args) catch "format error";

        if (self.enable_ansi) {
            const reset = "\x1b[0m";
            const color = switch (level) {
                .trace => "\x1b[90m",
                .debug => "\x1b[36m",
                .info => "\x1b[32m",
                .warn => "\x1b[33m",
                .@"error" => "\x1b[31m",
                else => "",
            };
            self.writer.print("[{d}] {s}{s}{s} {s}\n", .{ timestamp, color, level_name, reset, message }) catch {};
        } else {
            self.writer.print("[{d}] {s} {s}\n", .{ timestamp, level_name, message }) catch {};
        }
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

    pub fn warnFmt(self: *Logger, comptime format: []const u8, args: anytype) void {
        self.logFmt(.warn, format, args);
    }

    pub fn errorFmt(self: *Logger, comptime format: []const u8, args: anytype) void {
        self.logFmt(.@"error", format, args);
    }
};

pub fn supportsAnsiEscapeCodes() bool {
    if (std.os.getenv("NO_COLOR")) |_| {
        return false;
    }

    const stdout = std.io.getStdOut();
    if (stdout.supportsAnsiEscapeCodes()) {
        return true;
    }

    const stderr = std.io.getStdErr();
    if (stderr.supportsAnsiEscapeCodes()) {
        return true;
    }

    if (std.os.getenv("TERM")) |term| {
        if (std.mem.eql(u8, term, "dumb")) {
            return false;
        }
        return true;
    }

    return false;
}

pub fn parseLogLevel(level_str: []const u8) LogLevel {
    const upper = std.ascii.lowerString(level_str);
    if (std.mem.eql(u8, upper, "trace")) return .trace;
    if (std.mem.eql(u8, upper, "debug")) return .debug;
    if (std.mem.eql(u8, upper, "info")) return .info;
    if (std.mem.eql(u8, upper, "warn")) return .warn;
    if (std.mem.eql(u8, upper, "error")) return .@"error";
    if (std.mem.eql(u8, upper, "off")) return .off;
    return .info;
}
