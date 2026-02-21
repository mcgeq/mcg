const std = @import("std");

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

    pub fn log(self: *Logger, level: LogLevel, message: []const u8) void {
        if (!self.shouldLog(level)) return;

        const file = switch (level) {
            .@"error", .warn => std.fs.File.stderr(),
            else => std.fs.File.stdout(),
        };

        const level_name = getLevelName(level);
        const color = if (self.enable_ansi) getColor(level) else "";
        const reset = if (self.enable_ansi) ansi_colors.reset else "";

        // 使用固定缓冲区一次性构建完整输出
        var buf: [2048]u8 = undefined;
        var pos: usize = 0;

        // 写入颜色
        @memcpy(buf[pos .. pos + color.len], color);
        pos += color.len;

        // 写入 [LEVEL]
        buf[pos] = '[';
        pos += 1;
        @memcpy(buf[pos .. pos + level_name.len], level_name);
        pos += level_name.len;
        buf[pos] = ']';
        pos += 1;

        // 写入reset
        @memcpy(buf[pos .. pos + reset.len], reset);
        pos += reset.len;

        // 写入换行和缩进
        @memcpy(buf[pos .. pos + 5], "\n    ");
        pos += 5;

        // 写入消息（去除末尾的换行符，避免双换行）
        const msg_trimmed = if (message.len > 0 and message[message.len - 1] == '\n')
            message[0 .. message.len - 1]
        else
            message;
        @memcpy(buf[pos .. pos + msg_trimmed.len], msg_trimmed);
        pos += msg_trimmed.len;

        // 写入换行
        buf[pos] = '\n';
        pos += 1;

        _ = file.write(buf[0..pos]) catch {};
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

        const file = std.fs.File.stdout();
        const color = if (self.enable_ansi) ansi_colors.info else "";
        const reset = if (self.enable_ansi) ansi_colors.reset else "";

        // 预计算总大小
        var total_len: usize = color.len + 6 + reset.len + 1; // [INFO] + reset + \n
        for (messages) |msg| {
            total_len += 4 + msg.len + 1; // "    " + msg + "\n"
        }

        if (total_len > 4096) {
            // 消息太长，回退到多次写入
            _ = file.write(color) catch {};
            _ = file.write("[INFO]") catch {};
            _ = file.write(reset) catch {};
            _ = file.write("\n") catch {};

            for (messages) |msg| {
                var line_buf: [1024]u8 = undefined;
                const line = std.fmt.bufPrint(&line_buf, "    {s}\n", .{msg}) catch continue;
                _ = file.write(line) catch {};
            }
            return;
        }

        // 一次性构建完整输出
        var buf: [4096]u8 = undefined;
        var pos: usize = 0;

        @memcpy(buf[pos .. pos + color.len], color);
        pos += color.len;
        @memcpy(buf[pos .. pos + 6], "[INFO]");
        pos += 6;
        @memcpy(buf[pos .. pos + reset.len], reset);
        pos += reset.len;
        buf[pos] = '\n';
        pos += 1;

        for (messages) |msg| {
            @memcpy(buf[pos .. pos + 4], "    ");
            pos += 4;
            // 去除消息末尾的换行符
            const msg_trimmed = if (msg.len > 0 and msg[msg.len - 1] == '\n')
                msg[0 .. msg.len - 1]
            else
                msg;
            @memcpy(buf[pos .. pos + msg_trimmed.len], msg_trimmed);
            pos += msg_trimmed.len;
            buf[pos] = '\n';
            pos += 1;
        }

        _ = file.write(buf[0..pos]) catch {};
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
    const upper = std.ascii.lowerString(level_str);
    if (std.mem.eql(u8, upper, "trace")) return .trace;
    if (std.mem.eql(u8, upper, "debug")) return .debug;
    if (std.mem.eql(u8, upper, "info")) return .info;
    if (std.mem.eql(u8, upper, "warn")) return .warn;
    if (std.mem.eql(u8, upper, "error")) return .@"error";
    if (std.mem.eql(u8, upper, "off")) return .off;
    return .info;
}
