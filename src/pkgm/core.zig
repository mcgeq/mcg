/// Package manager interface module.
///
/// This module provides the unified interface for all package manager operations.
/// It combines detection, command registration, and execution into a simple API
/// that automatically handles the complexity of working with multiple package managers.
const std = @import("std");
const MgError = @import("../core/error.zig").MgError;
const CommandArgs = @import("../core/types.zig").CommandArgs;
const ManagerType = @import("../core/types.zig").ManagerType;
const PackageOptions = @import("../core/types.zig").PackageOptions;
const logger = @import("../core/logger.zig");
const runtime = @import("../core/runtime.zig");

pub const detect = @import("detect.zig");
pub const registry = @import("registry.zig");
pub const executor = @import("executor.zig");

pub const PlannedCommand = struct {
    manager_type: ManagerType,
    argv: std.ArrayList([]const u8),

    pub fn deinit(self: *PlannedCommand, allocator: std.mem.Allocator) void {
        self.argv.deinit(allocator);
    }
};

const DefaultCoreDeps = struct {
    fn plan(
        _: *const @This(),
        rt: *const runtime.Runtime,
        action: []const u8,
        command_args: *const CommandArgs,
        options: *const PackageOptions,
    ) MgError!PlannedCommand {
        const current_dir = std.process.currentPathAlloc(rt.io, rt.allocator) catch return error.CurrentDirFailed;
        defer rt.allocator.free(current_dir);

        return planCommandFromPathWithRuntime(rt, current_dir, action, command_args, options);
    }

    fn planFromPath(
        _: *const @This(),
        rt: *const runtime.Runtime,
        start_dir: []const u8,
        action: []const u8,
        command_args: *const CommandArgs,
        options: *const PackageOptions,
    ) MgError!PlannedCommand {
        return planCommandFromPathWithRuntime(rt, start_dir, action, command_args, options);
    }

    fn getManagerName(_: *const @This(), manager_type: ManagerType) []const u8 {
        return registry.getManagerName(manager_type);
    }

    fn executeArgvInCwd(
        _: *const @This(),
        argv: []const []const u8,
        dry_run: bool,
        cwd: ?[]const u8,
    ) MgError!void {
        try executor.executeArgvInCwd(argv, dry_run, cwd);
    }
};

/// Executes a package manager command for the detected project type.
///
/// This is the main entry point for package management operations. It:
///   1. Detects the package manager for the current project
///   2. Maps the action to the package manager's native command
///   3. Executes the command (or shows dry-run output)
///
/// Parameters:
///   - action: The action to perform (first character: a=add, r=remove, u=upgrade, etc.)
///   - command_args: Parsed package names and manager-native passthrough args
///   - options: Generic package options such as dry-run/dev/group
///
/// Returns:
///   MgError!void - Returns an error if detection or execution fails
///
/// Errors:
///   - error.NoPackageManager: No supported package manager detected
///   - error.UnknownSubcommand: Unknown action specified
///   - error.CommandFailed: The package manager command failed
///   - error.ManagerNotInstalled: The package manager is not installed
///
/// Example:
///   ```zig
///   // Add a package (auto-detects package manager)
///   var cmd_args = CommandArgs.init(allocator);
///   defer cmd_args.deinit();
///   try cmd_args.addPackage("lodash");
///   try pkgm.executeCommand("add", &cmd_args, &.{});
/// ```
pub fn planCommand(action: []const u8, command_args: *const CommandArgs, options: *const PackageOptions) MgError!PlannedCommand {
    const rt = runtime.get();
    const current_dir = std.process.currentPathAlloc(rt.io, rt.allocator) catch return error.CurrentDirFailed;
    defer rt.allocator.free(current_dir);

    return planCommandFromPathWithRuntime(rt, current_dir, action, command_args, options);
}

pub fn planCommandFromPath(
    start_dir: []const u8,
    action: []const u8,
    command_args: *const CommandArgs,
    options: *const PackageOptions,
) MgError!PlannedCommand {
    return planCommandFromPathWithRuntime(runtime.get(), start_dir, action, command_args, options);
}

pub fn planCommandFromPathWithRuntime(
    rt: *const runtime.Runtime,
    start_dir: []const u8,
    action: []const u8,
    command_args: *const CommandArgs,
    options: *const PackageOptions,
) MgError!PlannedCommand {
    const manager_type = detect.detectPackageManagerForCommandFromPathWithRuntime(rt, start_dir, action, command_args) orelse {
        return error.NoPackageManager;
    };

    return .{
        .manager_type = manager_type,
        .argv = try executor.buildArgv(rt.allocator, manager_type, action, command_args, options),
    };
}

pub fn executeCommand(action: []const u8, command_args: *const CommandArgs, options: *const PackageOptions) MgError!void {
    const rt = runtime.get();
    var deps = DefaultCoreDeps{};
    try executeCommandWithDeps(&deps, rt, action, command_args, options);
}

fn executeCommandWithDeps(
    deps: anytype,
    rt: *const runtime.Runtime,
    action: []const u8,
    command_args: *const CommandArgs,
    options: *const PackageOptions,
) MgError!void {
    var planned = blk: {
        const result = if (options.cwd) |cwd|
            deps.planFromPath(rt, cwd, action, command_args, options)
        else
            deps.plan(rt, action, command_args, options);

        break :blk result catch |err| {
            if (err == error.NoPackageManager) {
                logger.err("No supported package manager detected\n", .{});
            }
            return err;
        };
    };
    defer planned.deinit(rt.allocator);

    const manager_name = deps.getManagerName(planned.manager_type);
    logger.info("Using {s} package manager\n", .{manager_name});

    try deps.executeArgvInCwd(planned.argv.items, options.dry_run, options.cwd);
}

fn tmpProjectPath(allocator: std.mem.Allocator, tmp: *std.testing.TmpDir, sub_path: []const u8) ![]u8 {
    if (sub_path.len == 0) {
        return std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}", .{tmp.sub_path});
    }
    return std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/{s}", .{ tmp.sub_path, sub_path });
}

const RecordedPlan = struct {
    action: []const u8,
    start_dir: ?[]const u8 = null,
    dry_run: bool,
    cwd: ?[]const u8,
};

const RecordedExecute = struct {
    argv_len: usize,
    first_arg: ?[]const u8 = null,
    second_arg: ?[]const u8 = null,
    dry_run: bool,
    cwd: ?[]const u8,
};

const RecordingCoreDeps = struct {
    planned_manager_type: ManagerType = .npm,
    planned_argv: []const []const u8 = &.{ "npm", "install" },
    plan_count: usize = 0,
    plan_from_path_count: usize = 0,
    execute_count: usize = 0,
    fail_no_package_manager: bool = false,
    execute_error: ?MgError = null,
    last_plan: ?RecordedPlan = null,
    last_execute: ?RecordedExecute = null,

    fn makePlanned(self: *const @This(), allocator: std.mem.Allocator) !PlannedCommand {
        var argv: std.ArrayList([]const u8) = .empty;
        errdefer argv.deinit(allocator);

        for (self.planned_argv) |arg| {
            try argv.append(allocator, arg);
        }

        return .{
            .manager_type = self.planned_manager_type,
            .argv = argv,
        };
    }

    fn plan(
        self: *@This(),
        rt: *const runtime.Runtime,
        action: []const u8,
        _: *const CommandArgs,
        options: *const PackageOptions,
    ) MgError!PlannedCommand {
        self.plan_count += 1;
        self.last_plan = .{
            .action = action,
            .dry_run = options.dry_run,
            .cwd = options.cwd,
        };
        if (self.fail_no_package_manager) return error.NoPackageManager;
        return self.makePlanned(rt.allocator);
    }

    fn planFromPath(
        self: *@This(),
        rt: *const runtime.Runtime,
        start_dir: []const u8,
        action: []const u8,
        _: *const CommandArgs,
        options: *const PackageOptions,
    ) MgError!PlannedCommand {
        self.plan_from_path_count += 1;
        self.last_plan = .{
            .action = action,
            .start_dir = start_dir,
            .dry_run = options.dry_run,
            .cwd = options.cwd,
        };
        if (self.fail_no_package_manager) return error.NoPackageManager;
        return self.makePlanned(rt.allocator);
    }

    fn getManagerName(_: *const @This(), manager_type: ManagerType) []const u8 {
        return registry.getManagerName(manager_type);
    }

    fn executeArgvInCwd(
        self: *@This(),
        argv: []const []const u8,
        dry_run: bool,
        cwd: ?[]const u8,
    ) MgError!void {
        self.execute_count += 1;
        self.last_execute = .{
            .argv_len = argv.len,
            .first_arg = if (argv.len > 0) argv[0] else null,
            .second_arg = if (argv.len > 1) argv[1] else null,
            .dry_run = dry_run,
            .cwd = cwd,
        };

        if (self.execute_error) |err| return err;
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

test "planCommandFromPathWithRuntime resolves nested uv project command" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt: runtime.Runtime = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var nested_dir = try tmp.dir.createDirPathOpen(std.testing.io, "workspace/apps/demo", .{});
    nested_dir.close(std.testing.io);

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "workspace/pyproject.toml",
        .data =
        \\[project]
        \\name = "demo"
        \\version = "0.1.0"
        \\
        \\[tool.uv]
        \\package = true
        ,
    });

    const nested_path = try tmpProjectPath(std.testing.allocator, &tmp, "workspace/apps/demo");
    defer std.testing.allocator.free(nested_path);

    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();
    try command_args.addManagerArg("--frozen");

    var planned = try planCommandFromPathWithRuntime(
        &rt,
        nested_path,
        "install",
        &command_args,
        &.{ .group = "docs" },
    );
    defer planned.deinit(std.testing.allocator);

    try std.testing.expectEqual(ManagerType.uv, planned.manager_type);
    try std.testing.expectEqual(@as(usize, 5), planned.argv.items.len);
    try std.testing.expectEqualStrings("uv", planned.argv.items[0]);
    try std.testing.expectEqualStrings("sync", planned.argv.items[1]);
    try std.testing.expectEqualStrings("--group", planned.argv.items[2]);
    try std.testing.expectEqualStrings("docs", planned.argv.items[3]);
    try std.testing.expectEqualStrings("--frozen", planned.argv.items[4]);
}

test "planCommandFromPathWithRuntime resolves poetry dev add from nested directory" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt: runtime.Runtime = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var nested_dir = try tmp.dir.createDirPathOpen(std.testing.io, "workspace/packages/api", .{});
    nested_dir.close(std.testing.io);

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "workspace/poetry.lock",
        .data = "[[package]]\nname = \"demo\"\n",
    });

    const nested_path = try tmpProjectPath(std.testing.allocator, &tmp, "workspace/packages/api");
    defer std.testing.allocator.free(nested_path);

    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();
    try command_args.addPackage("pytest");

    var planned = try planCommandFromPathWithRuntime(
        &rt,
        nested_path,
        "add",
        &command_args,
        &.{ .dev = true },
    );
    defer planned.deinit(std.testing.allocator);

    try std.testing.expectEqual(ManagerType.poetry, planned.manager_type);
    try std.testing.expectEqualStrings("poetry", planned.argv.items[0]);
    try std.testing.expectEqualStrings("add", planned.argv.items[1]);
    try std.testing.expectEqualStrings("--group", planned.argv.items[2]);
    try std.testing.expectEqualStrings("dev", planned.argv.items[3]);
    try std.testing.expectEqualStrings("pytest", planned.argv.items[4]);
}

test "planCommandFromPathWithRuntime resolves pdm grouped install" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt: runtime.Runtime = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "pdm.lock",
        .data = "[metadata]\nlock_version = \"4.0\"\n",
    });

    const project_path = try tmpProjectPath(std.testing.allocator, &tmp, "");
    defer std.testing.allocator.free(project_path);

    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();

    var planned = try planCommandFromPathWithRuntime(
        &rt,
        project_path,
        "install",
        &command_args,
        &.{ .group = "test" },
    );
    defer planned.deinit(std.testing.allocator);

    try std.testing.expectEqual(ManagerType.pdm, planned.manager_type);
    try std.testing.expectEqual(@as(usize, 4), planned.argv.items.len);
    try std.testing.expectEqualStrings("pdm", planned.argv.items[0]);
    try std.testing.expectEqualStrings("install", planned.argv.items[1]);
    try std.testing.expectEqualStrings("--group", planned.argv.items[2]);
    try std.testing.expectEqualStrings("test", planned.argv.items[3]);
}

test "planCommandFromPathWithRuntime resolves npm dev add from lockfile" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt: runtime.Runtime = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "package-lock.json",
        .data = "{\n  \"name\": \"demo\"\n}\n",
    });

    const project_path = try tmpProjectPath(std.testing.allocator, &tmp, "");
    defer std.testing.allocator.free(project_path);

    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();
    try command_args.addPackage("vitest");

    var planned = try planCommandFromPathWithRuntime(
        &rt,
        project_path,
        "add",
        &command_args,
        &.{ .dev = true },
    );
    defer planned.deinit(std.testing.allocator);

    try std.testing.expectEqual(ManagerType.npm, planned.manager_type);
    try std.testing.expectEqual(@as(usize, 4), planned.argv.items.len);
    try std.testing.expectEqualStrings("npm", planned.argv.items[0]);
    try std.testing.expectEqualStrings("install", planned.argv.items[1]);
    try std.testing.expectEqualStrings("--save-dev", planned.argv.items[2]);
    try std.testing.expectEqualStrings("vitest", planned.argv.items[3]);
}

test "planCommandFromPathWithRuntime resolves pnpm install from packageManager without lockfile" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt: runtime.Runtime = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "package.json",
        .data =
        \\{
        \\  "name": "demo",
        \\  "packageManager": "pnpm@9.12.0"
        \\}
        ,
    });

    const project_path = try tmpProjectPath(std.testing.allocator, &tmp, "");
    defer std.testing.allocator.free(project_path);

    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();

    var planned = try planCommandFromPathWithRuntime(
        &rt,
        project_path,
        "install",
        &command_args,
        &.{},
    );
    defer planned.deinit(std.testing.allocator);

    try std.testing.expectEqual(ManagerType.pnpm, planned.manager_type);
    try std.testing.expectEqualStrings("pnpm", planned.argv.items[0]);
    try std.testing.expectEqualStrings("install", planned.argv.items[1]);
}

test "planCommandFromPathWithRuntime falls back to npm for plain package.json" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt: runtime.Runtime = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "package.json",
        .data =
        \\{
        \\  "name": "demo",
        \\  "version": "1.0.0"
        \\}
        ,
    });

    const project_path = try tmpProjectPath(std.testing.allocator, &tmp, "");
    defer std.testing.allocator.free(project_path);

    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();
    try command_args.addPackage("vite");

    var planned = try planCommandFromPathWithRuntime(
        &rt,
        project_path,
        "add",
        &command_args,
        &.{},
    );
    defer planned.deinit(std.testing.allocator);

    try std.testing.expectEqual(ManagerType.npm, planned.manager_type);
    try std.testing.expectEqualStrings("npm", planned.argv.items[0]);
    try std.testing.expectEqualStrings("install", planned.argv.items[1]);
    try std.testing.expectEqualStrings("vite", planned.argv.items[2]);
}

test "planCommandFromPathWithRuntime upgrades child plain package json to parent pnpm workspace" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt: runtime.Runtime = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var nested_dir = try tmp.dir.createDirPathOpen(std.testing.io, "workspace/packages/app", .{});
    nested_dir.close(std.testing.io);

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "workspace/package.json",
        .data =
        \\{
        \\  "name": "workspace-root",
        \\  "packageManager": "pnpm@9.12.0"
        \\}
        ,
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "workspace/packages/app/package.json",
        .data =
        \\{
        \\  "name": "app",
        \\  "version": "1.0.0"
        \\}
        ,
    });

    const nested_path = try tmpProjectPath(std.testing.allocator, &tmp, "workspace/packages/app");
    defer std.testing.allocator.free(nested_path);

    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();

    var planned = try planCommandFromPathWithRuntime(
        &rt,
        nested_path,
        "install",
        &command_args,
        &.{},
    );
    defer planned.deinit(std.testing.allocator);

    try std.testing.expectEqual(ManagerType.pnpm, planned.manager_type);
    try std.testing.expectEqualStrings("pnpm", planned.argv.items[0]);
    try std.testing.expectEqualStrings("install", planned.argv.items[1]);
}

test "planCommandFromPathWithRuntime keeps child plain package json over parent cargo root" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt: runtime.Runtime = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var nested_dir = try tmp.dir.createDirPathOpen(std.testing.io, "workspace/apps/web", .{});
    nested_dir.close(std.testing.io);

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "workspace/Cargo.toml",
        .data =
        \\[package]
        \\name = "workspace-root"
        \\version = "0.1.0"
        ,
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "workspace/apps/web/package.json",
        .data =
        \\{
        \\  "name": "web",
        \\  "version": "1.0.0"
        \\}
        ,
    });

    const nested_path = try tmpProjectPath(std.testing.allocator, &tmp, "workspace/apps/web");
    defer std.testing.allocator.free(nested_path);

    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();
    try command_args.addPackage("vite");

    var planned = try planCommandFromPathWithRuntime(
        &rt,
        nested_path,
        "add",
        &command_args,
        &.{},
    );
    defer planned.deinit(std.testing.allocator);

    try std.testing.expectEqual(ManagerType.npm, planned.manager_type);
    try std.testing.expectEqualStrings("npm", planned.argv.items[0]);
    try std.testing.expectEqualStrings("install", planned.argv.items[1]);
    try std.testing.expectEqualStrings("vite", planned.argv.items[2]);
}

test "planCommandFromPathWithRuntime resolves project from relative cwd" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt: runtime.Runtime = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var nested_dir = try tmp.dir.createDirPathOpen(std.testing.io, "repo/services/api", .{});
    nested_dir.close(std.testing.io);

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "repo/package-lock.json",
        .data = "{\n  \"name\": \"demo\"\n}\n",
    });

    const relative_path = try std.fmt.allocPrint(
        std.testing.allocator,
        ".zig-cache/tmp/{s}/repo/services/api",
        .{tmp.sub_path},
    );
    defer std.testing.allocator.free(relative_path);

    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();
    try command_args.addPackage("eslint");

    var planned = try planCommandFromPathWithRuntime(
        &rt,
        relative_path,
        "add",
        &command_args,
        &.{ .dev = true, .cwd = relative_path },
    );
    defer planned.deinit(std.testing.allocator);

    try std.testing.expectEqual(ManagerType.npm, planned.manager_type);
    try std.testing.expectEqualStrings("npm", planned.argv.items[0]);
    try std.testing.expectEqualStrings("install", planned.argv.items[1]);
    try std.testing.expectEqualStrings("--save-dev", planned.argv.items[2]);
    try std.testing.expectEqualStrings("eslint", planned.argv.items[3]);
}

test "planCommandFromPathWithRuntime upgrades child run script to parent pnpm workspace manager" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt: runtime.Runtime = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var nested_dir = try tmp.dir.createDirPathOpen(std.testing.io, "workspace/packages/app", .{});
    nested_dir.close(std.testing.io);

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "workspace/package.json",
        .data =
        \\{
        \\  "name": "workspace-root",
        \\  "packageManager": "pnpm@9.12.0"
        \\}
        ,
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "workspace/packages/app/package.json",
        .data =
        \\{
        \\  "name": "app",
        \\  "scripts": {
        \\    "build": "node build.js"
        \\  }
        \\}
        ,
    });

    const nested_path = try tmpProjectPath(std.testing.allocator, &tmp, "workspace/packages/app");
    defer std.testing.allocator.free(nested_path);

    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();
    try command_args.addPackage("build");

    var planned = try planCommandFromPathWithRuntime(
        &rt,
        nested_path,
        "run",
        &command_args,
        &.{},
    );
    defer planned.deinit(std.testing.allocator);

    try std.testing.expectEqual(ManagerType.pnpm, planned.manager_type);
    try std.testing.expectEqualStrings("pnpm", planned.argv.items[0]);
    try std.testing.expectEqualStrings("run", planned.argv.items[1]);
    try std.testing.expectEqualStrings("build", planned.argv.items[2]);
}

test "planCommandFromPathWithRuntime prefers node run script over cargo in mixed repository" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt: runtime.Runtime = .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = &environ_map,
    };

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "Cargo.toml",
        .data =
        \\[package]
        \\name = "demo"
        \\version = "0.1.0"
        ,
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "package-lock.json",
        .data = "{\n  \"name\": \"demo\"\n}\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "package.json",
        .data =
        \\{
        \\  "name": "demo",
        \\  "scripts": {
        \\    "build:apk": "echo build apk"
        \\  }
        \\}
        ,
    });

    const project_path = try tmpProjectPath(std.testing.allocator, &tmp, "");
    defer std.testing.allocator.free(project_path);

    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();
    try command_args.addPackage("build:apk");

    var planned = try planCommandFromPathWithRuntime(
        &rt,
        project_path,
        "run",
        &command_args,
        &.{},
    );
    defer planned.deinit(std.testing.allocator);

    try std.testing.expectEqual(ManagerType.npm, planned.manager_type);
    try std.testing.expectEqual(@as(usize, 3), planned.argv.items.len);
    try std.testing.expectEqualStrings("npm", planned.argv.items[0]);
    try std.testing.expectEqualStrings("run", planned.argv.items[1]);
    try std.testing.expectEqualStrings("build:apk", planned.argv.items[2]);
}

test "executeCommandWithDeps plans from cwd and forwards dry-run to executor" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    const rt = setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var deps: RecordingCoreDeps = .{
        .planned_manager_type = .uv,
        .planned_argv = &.{ "uv", "sync", "--frozen" },
    };
    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();

    try executeCommandWithDeps(
        &deps,
        &rt,
        "install",
        &command_args,
        &.{ .dry_run = true, .cwd = "workspace/api" },
    );

    try std.testing.expectEqual(@as(usize, 0), deps.plan_count);
    try std.testing.expectEqual(@as(usize, 1), deps.plan_from_path_count);
    try std.testing.expectEqualStrings("install", deps.last_plan.?.action);
    try std.testing.expectEqualStrings("workspace/api", deps.last_plan.?.start_dir.?);
    try std.testing.expect(deps.last_plan.?.dry_run);
    try std.testing.expectEqual(@as(usize, 1), deps.execute_count);
    try std.testing.expectEqual(@as(usize, 3), deps.last_execute.?.argv_len);
    try std.testing.expectEqualStrings("uv", deps.last_execute.?.first_arg.?);
    try std.testing.expectEqualStrings("sync", deps.last_execute.?.second_arg.?);
    try std.testing.expect(deps.last_execute.?.dry_run);
    try std.testing.expectEqualStrings("workspace/api", deps.last_execute.?.cwd.?);
}

test "executeCommandWithDeps uses default planning path when cwd is absent" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    const rt = setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var deps: RecordingCoreDeps = .{
        .planned_manager_type = .npm,
        .planned_argv = &.{ "npm", "install", "vite" },
    };
    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();
    try command_args.addPackage("vite");

    try executeCommandWithDeps(
        &deps,
        &rt,
        "add",
        &command_args,
        &.{ .dry_run = true },
    );

    try std.testing.expectEqual(@as(usize, 1), deps.plan_count);
    try std.testing.expectEqual(@as(usize, 0), deps.plan_from_path_count);
    try std.testing.expectEqualStrings("add", deps.last_plan.?.action);
    try std.testing.expect(deps.last_plan.?.cwd == null);
    try std.testing.expectEqual(@as(usize, 1), deps.execute_count);
    try std.testing.expectEqualStrings("npm", deps.last_execute.?.first_arg.?);
    try std.testing.expectEqualStrings("install", deps.last_execute.?.second_arg.?);
    try std.testing.expect(deps.last_execute.?.cwd == null);
}

test "executeCommandWithDeps returns no package manager without executing" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    const rt = setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var deps: RecordingCoreDeps = .{
        .fail_no_package_manager = true,
    };
    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();

    try std.testing.expectError(
        error.NoPackageManager,
        executeCommandWithDeps(
            &deps,
            &rt,
            "install",
            &command_args,
            &.{ .cwd = "workspace/api" },
        ),
    );

    try std.testing.expectEqual(@as(usize, 0), deps.plan_count);
    try std.testing.expectEqual(@as(usize, 1), deps.plan_from_path_count);
    try std.testing.expectEqual(@as(usize, 0), deps.execute_count);
}

test "executeCommandWithDeps propagates executor failure" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    const rt = setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var deps: RecordingCoreDeps = .{
        .planned_manager_type = .poetry,
        .planned_argv = &.{ "poetry", "install" },
        .execute_error = error.ManagerNotInstalled,
    };
    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();

    try std.testing.expectError(
        error.ManagerNotInstalled,
        executeCommandWithDeps(
            &deps,
            &rt,
            "install",
            &command_args,
            &.{ .dry_run = false, .cwd = "workspace/api" },
        ),
    );

    try std.testing.expectEqual(@as(usize, 1), deps.plan_from_path_count);
    try std.testing.expectEqual(@as(usize, 1), deps.execute_count);
    try std.testing.expectEqualStrings("poetry", deps.last_execute.?.first_arg.?);
    try std.testing.expectEqualStrings("workspace/api", deps.last_execute.?.cwd.?);
}

test "executeCommandWithDeps writes selected manager to captured stdout" {
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

    var deps: RecordingCoreDeps = .{
        .planned_manager_type = .uv,
        .planned_argv = &.{ "uv", "sync", "--frozen" },
    };
    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();

    try executeCommandWithDeps(
        &deps,
        &rt,
        "install",
        &command_args,
        &.{ .dry_run = true, .cwd = "workspace/api" },
    );

    try std.testing.expectEqualStrings(
        "[INFO]\n    Using uv package manager\n",
        capture.stdout.items,
    );
    try std.testing.expectEqual(@as(usize, 0), capture.stderr.items.len);
}

test "executeCommandWithDeps writes no package manager error to captured stderr" {
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

    var deps: RecordingCoreDeps = .{
        .fail_no_package_manager = true,
    };
    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();

    try std.testing.expectError(
        error.NoPackageManager,
        executeCommandWithDeps(
            &deps,
            &rt,
            "install",
            &command_args,
            &.{ .cwd = "workspace/api" },
        ),
    );

    try std.testing.expectEqualStrings(
        "[ERROR]\n    No supported package manager detected\n",
        capture.stderr.items,
    );
    try std.testing.expectEqual(@as(usize, 0), capture.stdout.items.len);
}
