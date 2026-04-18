const std = @import("std");

pub const Runtime = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *std.process.Environ.Map,
    fs_cwd: ?[]const u8 = null,
    stdout_sink: ?OutputSink = null,
    stderr_sink: ?OutputSink = null,
};

pub const OutputTarget = enum {
    stdout,
    stderr,
};

pub const OutputSink = struct {
    context: *anyopaque,
    writeFn: *const fn (context: *anyopaque, bytes: []const u8) void,

    pub fn write(self: @This(), bytes: []const u8) void {
        self.writeFn(self.context, bytes);
    }
};

var current_runtime: ?Runtime = null;

pub fn isInitialized() bool {
    return current_runtime != null;
}

pub fn set(runtime: Runtime) void {
    current_runtime = runtime;
}

fn getMutable() *Runtime {
    if (current_runtime == null) {
        std.debug.panic("mg runtime is not initialized", .{});
    }
    return &current_runtime.?;
}

pub fn get() *const Runtime {
    if (current_runtime == null) {
        std.debug.panic("mg runtime is not initialized", .{});
    }
    return &current_runtime.?;
}

pub fn getFsCwd() ?[]const u8 {
    return get().fs_cwd;
}

pub fn swapFsCwd(path: ?[]const u8) ?[]const u8 {
    const runtime = getMutable();
    const previous = runtime.fs_cwd;
    runtime.fs_cwd = path;
    return previous;
}

pub fn swapOutputSink(target: OutputTarget, sink: ?OutputSink) ?OutputSink {
    const runtime = getMutable();
    const slot = switch (target) {
        .stdout => &runtime.stdout_sink,
        .stderr => &runtime.stderr_sink,
    };
    const previous = slot.*;
    slot.* = sink;
    return previous;
}

fn writeToFile(file: std.Io.File, bytes: []const u8) void {
    var writer_buf: [256]u8 = undefined;
    var writer = file.writer(get().io, &writer_buf);
    writer.interface.writeAll(bytes) catch {};
    writer.interface.flush() catch {};
}

fn writeOutput(target: OutputTarget, bytes: []const u8) void {
    if (bytes.len == 0) return;

    const sink = switch (target) {
        .stdout => get().stdout_sink,
        .stderr => get().stderr_sink,
    };
    if (sink) |captured| {
        captured.write(bytes);
        return;
    }

    const file = switch (target) {
        .stdout => std.Io.File.stdout(),
        .stderr => std.Io.File.stderr(),
    };
    writeToFile(file, bytes);
}

pub fn writeStdout(bytes: []const u8) void {
    writeOutput(.stdout, bytes);
}

pub fn writeStderr(bytes: []const u8) void {
    writeOutput(.stderr, bytes);
}
