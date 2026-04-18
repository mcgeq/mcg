/// Package manager command executor.
///
/// This module handles the actual execution of package manager commands.
/// It builds the command string, spawns the child process, and manages
/// the execution lifecycle including error handling and dry-run support.
const std = @import("std");
const CommandArgs = @import("../core/types.zig").CommandArgs;
const MgError = @import("../core/error.zig").MgError;
const ManagerType = @import("../core/types.zig").ManagerType;
const PackageOptions = @import("../core/types.zig").PackageOptions;
const registry = @import("registry.zig");
const logger = @import("../core/logger.zig");
const runtime = @import("../core/runtime.zig");

const DefaultExecutorDeps = struct {
    fn formatPreview(
        _: *const @This(),
        allocator: std.mem.Allocator,
        argv: []const []const u8,
        cwd: ?[]const u8,
    ) ![]u8 {
        return formatCommandPreview(allocator, argv, cwd);
    }

    fn runProcess(
        _: *const @This(),
        io: std.Io,
        argv: []const []const u8,
        cwd: ?[]const u8,
    ) MgError!void {
        var child = std.process.spawn(io, .{
            .argv = argv,
            .cwd = if (cwd) |path| .{ .path = path } else .inherit,
            .stdin = .inherit,
            .stdout = .inherit,
            .stderr = .inherit,
        }) catch |err| {
            logger.err("Failed to spawn process: {s}\n", .{@errorName(err)});
            return switch (err) {
                error.FileNotFound => error.ManagerNotInstalled,
                else => error.CommandFailed,
            };
        };

        const term = child.wait(io) catch |err| {
            logger.err("Failed to wait for process: {s}\n", .{@errorName(err)});
            return error.CommandFailed;
        };

        switch (term) {
            .exited => |code| {
                if (code != 0) {
                    logger.err("Command failed with exit code {d}\n", .{code});
                    return error.CommandFailed;
                }
            },
            else => {
                logger.err("Command terminated unexpectedly\n", .{});
                return error.CommandFailed;
            },
        }
    }
};

/// Executes a package manager command.
///
/// This function builds the complete command from the manager type, action,
/// and package list, then either displays it (dry-run mode) or executes it.
///
/// Parameters:
///   - manager_type: The detected package manager type
///   - action: The action to perform (add, remove, upgrade, etc.)
///   - command_args: Parsed package names and manager-native passthrough args
///   - options: Generic package options such as dry-run/dev/group
///
/// Returns:
///   MgError!void - Returns an error if command execution fails
///
/// Process:
///   1. Build the native command argv from the registry
///   2. Build the full command string
///   3. If dry_run, print and return
///   4. Spawn the child process with the package manager
///   5. Wait for completion and check exit code
///   6. Return error if exit code is non-zero
///
/// Errors:
///   - error.UnknownSubcommand: If the action is not recognized
///   - error.CommandFailed: If the spawned process fails or exits with non-zero code
///   - error.ManagerNotInstalled: If the package manager executable is not found
///
/// Example:
///   ```zig
///   var cmd_args = CommandArgs.init(allocator);
///   defer cmd_args.deinit();
///   try cmd_args.addPackage("lodash");
///   try executor.execute(.npm, "add", &cmd_args, &.{});
/// ```
pub fn buildArgv(
    allocator: std.mem.Allocator,
    manager_type: ManagerType,
    action: []const u8,
    command_args: *const CommandArgs,
    options: *const PackageOptions,
) MgError!std.ArrayList([]const u8) {
    var argv: std.ArrayList([]const u8) = .empty;
    errdefer argv.deinit(allocator);

    argv.append(allocator, registry.getManagerName(manager_type)) catch return error.CommandFailed;
    const found = registry.appendCommandArgs(
        &argv,
        allocator,
        manager_type,
        action,
        command_args,
        options,
    ) catch return error.CommandFailed;
    if (!found) {
        return error.UnknownSubcommand;
    }

    return argv;
}

fn previewTokenNeedsQuoting(token: []const u8) bool {
    if (token.len == 0) return true;

    for (token) |char| {
        switch (char) {
            ' ', '\t', '\n', '\r', '"', '\'' => return true,
            else => {},
        }
    }

    return false;
}

fn appendPreviewToken(
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    token: []const u8,
) !void {
    if (!previewTokenNeedsQuoting(token)) {
        try out.appendSlice(allocator, token);
        return;
    }

    try out.append(allocator, '"');
    for (token) |char| {
        switch (char) {
            '"' => try out.appendSlice(allocator, "\\\""),
            '\\' => try out.appendSlice(allocator, "\\\\"),
            '\n' => try out.appendSlice(allocator, "\\n"),
            '\r' => try out.appendSlice(allocator, "\\r"),
            '\t' => try out.appendSlice(allocator, "\\t"),
            else => try out.append(allocator, char),
        }
    }
    try out.append(allocator, '"');
}

pub fn formatCommandPreview(
    allocator: std.mem.Allocator,
    argv: []const []const u8,
    cwd: ?[]const u8,
) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    if (cwd) |path| {
        try out.appendSlice(allocator, "[cwd=");
        try appendPreviewToken(&out, allocator, path);
        try out.appendSlice(allocator, "] ");
    }

    for (argv, 0..) |part, idx| {
        if (idx != 0) {
            try out.append(allocator, ' ');
        }
        try appendPreviewToken(&out, allocator, part);
    }

    return out.toOwnedSlice(allocator);
}

pub fn execute(
    manager_type: ManagerType,
    action: []const u8,
    command_args: *const CommandArgs,
    options: *const PackageOptions,
) MgError!void {
    var argv = try buildArgv(std.heap.page_allocator, manager_type, action, command_args, options);
    defer argv.deinit(std.heap.page_allocator);

    try executeArgvInCwd(argv.items, options.dry_run, options.cwd);
}

pub fn executeArgv(argv: []const []const u8, dry_run: bool) MgError!void {
    return executeArgvInCwd(argv, dry_run, null);
}

pub fn executeArgvInCwd(argv: []const []const u8, dry_run: bool, cwd: ?[]const u8) MgError!void {
    const rt = runtime.get();
    var deps = DefaultExecutorDeps{};
    try executeArgvInCwdWithDeps(&deps, rt, argv, dry_run, cwd);
}

fn executeArgvInCwdWithDeps(
    deps: anytype,
    rt: *const runtime.Runtime,
    argv: []const []const u8,
    dry_run: bool,
    cwd: ?[]const u8,
) MgError!void {
    if (argv.len == 0) return error.CommandFailed;

    const preview = deps.formatPreview(rt.allocator, argv, cwd) catch return error.CommandFailed;
    defer rt.allocator.free(preview);

    logger.info("Executing: {s}\n", .{preview});

    if (dry_run) {
        logger.debug("Dry run - command not executed\n", .{});
        return;
    }

    try deps.runProcess(rt.io, argv, cwd);

    logger.info("Command completed successfully\n", .{});
}

const RecordedPreviewRequest = struct {
    argv_len: usize,
    first_arg: ?[]const u8 = null,
    cwd: ?[]const u8 = null,
};

const RecordedProcessRun = struct {
    argv_len: usize,
    first_arg: ?[]const u8 = null,
    second_arg: ?[]const u8 = null,
    cwd: ?[]const u8 = null,
};

const RecordingExecutorDeps = struct {
    preview_value: []const u8 = "npm install vite",
    preview_count: usize = 0,
    process_count: usize = 0,
    fail_preview: bool = false,
    process_error: ?MgError = null,
    last_preview_request: ?RecordedPreviewRequest = null,
    last_process_run: ?RecordedProcessRun = null,

    fn formatPreview(
        self: *@This(),
        allocator: std.mem.Allocator,
        argv: []const []const u8,
        cwd: ?[]const u8,
    ) ![]u8 {
        self.preview_count += 1;
        self.last_preview_request = .{
            .argv_len = argv.len,
            .first_arg = if (argv.len > 0) argv[0] else null,
            .cwd = cwd,
        };
        if (self.fail_preview) return error.OutOfMemory;
        return allocator.dupe(u8, self.preview_value);
    }

    fn runProcess(
        self: *@This(),
        _: std.Io,
        argv: []const []const u8,
        cwd: ?[]const u8,
    ) MgError!void {
        self.process_count += 1;
        self.last_process_run = .{
            .argv_len = argv.len,
            .first_arg = if (argv.len > 0) argv[0] else null,
            .second_arg = if (argv.len > 1) argv[1] else null,
            .cwd = cwd,
        };
        if (self.process_error) |err| return err;
    }
};

fn setTestRuntime(environ_map: *std.process.Environ.Map) runtime.Runtime {
    const rt: runtime.Runtime = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = environ_map,
    };
    runtime.set(rt);
    return rt;
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

test "buildArgv returns final uv sync command with group and passthrough args" {
    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();

    try command_args.addManagerArg("--frozen");

    var argv = try buildArgv(
        std.testing.allocator,
        .uv,
        "install",
        &command_args,
        &.{ .group = "docs" },
    );
    defer argv.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 5), argv.items.len);
    try std.testing.expectEqualStrings("uv", argv.items[0]);
    try std.testing.expectEqualStrings("sync", argv.items[1]);
    try std.testing.expectEqualStrings("--group", argv.items[2]);
    try std.testing.expectEqualStrings("docs", argv.items[3]);
    try std.testing.expectEqualStrings("--frozen", argv.items[4]);
}

test "formatCommandPreview joins argv without cwd" {
    const preview = try formatCommandPreview(
        std.testing.allocator,
        &.{ "npm", "install", "vite" },
        null,
    );
    defer std.testing.allocator.free(preview);

    try std.testing.expectEqualStrings("npm install vite", preview);
}

test "formatCommandPreview includes cwd prefix" {
    const preview = try formatCommandPreview(
        std.testing.allocator,
        &.{ "npm", "install", "vite" },
        "apps/web",
    );
    defer std.testing.allocator.free(preview);

    try std.testing.expectEqualStrings("[cwd=apps/web] npm install vite", preview);
}

test "formatCommandPreview quotes whitespace and passthrough args" {
    const preview = try formatCommandPreview(
        std.testing.allocator,
        &.{
            "uv",
            "sync",
            "--project",
            "apps/api tools",
            "--python",
            "C:\\Program Files\\Python\\python.exe",
        },
        "workspace tools",
    );
    defer std.testing.allocator.free(preview);

    try std.testing.expectEqualStrings(
        "[cwd=\"workspace tools\"] uv sync --project \"apps/api tools\" --python \"C:\\\\Program Files\\\\Python\\\\python.exe\"",
        preview,
    );
}

test "buildArgv returns error for unknown command" {
    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();

    try std.testing.expectError(
        error.UnknownSubcommand,
        buildArgv(std.testing.allocator, .npm, "publish", &command_args, &.{}),
    );
}

test "executeArgvInCwdWithDeps dry-run formats preview without spawning" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    const rt = setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var deps: RecordingExecutorDeps = .{
        .preview_value = "[cwd=apps/web] npm install vite",
    };

    try executeArgvInCwdWithDeps(
        &deps,
        &rt,
        &.{ "npm", "install", "vite" },
        true,
        "apps/web",
    );

    try std.testing.expectEqual(@as(usize, 1), deps.preview_count);
    try std.testing.expectEqual(@as(usize, 0), deps.process_count);
    try std.testing.expectEqual(@as(usize, 3), deps.last_preview_request.?.argv_len);
    try std.testing.expectEqualStrings("npm", deps.last_preview_request.?.first_arg.?);
    try std.testing.expectEqualStrings("apps/web", deps.last_preview_request.?.cwd.?);
}

test "executeArgvInCwdWithDeps forwards argv and cwd to process runner" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    const rt = setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var deps: RecordingExecutorDeps = .{
        .preview_value = "uv sync --frozen",
    };

    try executeArgvInCwdWithDeps(
        &deps,
        &rt,
        &.{ "uv", "sync", "--frozen" },
        false,
        "workspace/api",
    );

    try std.testing.expectEqual(@as(usize, 1), deps.preview_count);
    try std.testing.expectEqual(@as(usize, 1), deps.process_count);
    try std.testing.expectEqual(@as(usize, 3), deps.last_process_run.?.argv_len);
    try std.testing.expectEqualStrings("uv", deps.last_process_run.?.first_arg.?);
    try std.testing.expectEqualStrings("sync", deps.last_process_run.?.second_arg.?);
    try std.testing.expectEqualStrings("workspace/api", deps.last_process_run.?.cwd.?);
}

test "executeArgvInCwdWithDeps propagates process failure" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    const rt = setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var deps: RecordingExecutorDeps = .{
        .preview_value = "poetry install",
        .process_error = error.ManagerNotInstalled,
    };

    try std.testing.expectError(
        error.ManagerNotInstalled,
        executeArgvInCwdWithDeps(
            &deps,
            &rt,
            &.{ "poetry", "install" },
            false,
            "workspace/api",
        ),
    );

    try std.testing.expectEqual(@as(usize, 1), deps.preview_count);
    try std.testing.expectEqual(@as(usize, 1), deps.process_count);
}

test "executeArgvInCwdWithDeps rejects empty argv" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    const rt = setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var deps = RecordingExecutorDeps{};

    try std.testing.expectError(
        error.CommandFailed,
        executeArgvInCwdWithDeps(&deps, &rt, &.{}, true, null),
    );

    try std.testing.expectEqual(@as(usize, 0), deps.preview_count);
    try std.testing.expectEqual(@as(usize, 0), deps.process_count);
}

test "executeArgvInCwdWithDeps dry-run writes preview to captured stdout" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    const rt = setTestRuntime(&environ_map);

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

    var deps: RecordingExecutorDeps = .{
        .preview_value = "[cwd=apps/web] npm install vite",
    };

    try executeArgvInCwdWithDeps(
        &deps,
        &rt,
        &.{ "npm", "install", "vite" },
        true,
        "apps/web",
    );

    try std.testing.expectEqualStrings(
        "[INFO]\n    Executing: [cwd=apps/web] npm install vite\n",
        capture.stdout.items,
    );
    try std.testing.expectEqual(@as(usize, 0), capture.stderr.items.len);
}

test "executeArgvInCwdWithDeps success writes completion to captured stdout" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    const rt = setTestRuntime(&environ_map);

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

    var deps: RecordingExecutorDeps = .{
        .preview_value = "uv sync --frozen",
    };

    try executeArgvInCwdWithDeps(
        &deps,
        &rt,
        &.{ "uv", "sync", "--frozen" },
        false,
        "workspace/api",
    );

    try std.testing.expectEqualStrings(
        "[INFO]\n    Executing: uv sync --frozen\n[INFO]\n    Command completed successfully\n",
        capture.stdout.items,
    );
    try std.testing.expectEqual(@as(usize, 0), capture.stderr.items.len);
}
