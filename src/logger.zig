const std = @import("std");

fn getLocalTime() struct { hour: u32, minute: u32, second: u32 } {
    const timestamp = std.time.timestamp();
    const tz_offset: i64 = 8 * 3600;
    const local_ts = timestamp + tz_offset;

    const seconds_since_midnight = @mod(local_ts, 86400);
    const hour = @as(u32, @intCast(@divTrunc(seconds_since_midnight, 3600)));
    const minute = @as(u32, @intCast(@divTrunc(@mod(seconds_since_midnight, 3600), 60)));
    const second = @as(u32, @intCast(@mod(seconds_since_midnight, 60)));

    return .{
        .hour = hour,
        .minute = minute,
        .second = second,
    };
}

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

    pub fn log(self: *Logger, level: LogLevel, message: []const u8) void {
        if (!self.shouldLog(level)) return;

        const level_name = @tagName(level);
        var level_name_upper: [16]u8 = undefined;
        @memcpy(level_name_upper[0..level_name.len], level_name);
        for (0..level_name.len) |i| {
            level_name_upper[i] = std.ascii.toUpper(level_name_upper[i]);
        }

        const ts = getLocalTime();

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
            std.debug.print("[{d:02}:{d:02}:{d:02}] {s}{s}{s} {s}\n", .{ ts.hour, ts.minute, ts.second, color, level_name_upper[0..level_name.len], reset, message });
        } else {
            std.debug.print("[{d:02}:{d:02}:{d:02}] {s} {s}\n", .{ ts.hour, ts.minute, ts.second, level_name_upper[0..level_name.len], message });
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

        var buf: [4096]u8 = undefined;
        const message = std.fmt.bufPrint(&buf, format, args) catch "format error";

        const level_name = @tagName(level);
        var level_name_upper: [16]u8 = undefined;
        @memcpy(level_name_upper[0..level_name.len], level_name);
        for (0..level_name.len) |i| {
            level_name_upper[i] = std.ascii.toUpper(level_name_upper[i]);
        }

        const ts = getLocalTime();

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
            std.debug.print("[{d:02}:{d:02}:{d:02}] {s}{s}{s} {s}\n", .{ ts.hour, ts.minute, ts.second, color, level_name_upper[0..level_name.len], reset, message });
        } else {
            std.debug.print("[{d:02}:{d:02}:{d:02}] {s} {s}\n", .{ ts.hour, ts.minute, ts.second, level_name_upper[0..level_name.len], message });
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

pub inline fn debug(comptime fmt: []const u8, args: anytype) void {
    getLogger().debugFmt(fmt, args);
}

pub inline fn trace(comptime fmt: []const u8, args: anytype) void {
    getLogger().traceFmt(fmt, args);
}

pub fn flushLogger() void {}

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
