/// Package manager detection module.
///
/// This module provides functionality to detect the appropriate package manager
/// for the current project by scanning for lock files in the working directory.
/// The detection follows a priority-based approach where lower numbers indicate
/// higher priority (checked first).
const std = @import("std");
const CommandArgs = @import("../core/types.zig").CommandArgs;
const ManagerType = @import("../core/types.zig").ManagerType;
const runtime = @import("../core/runtime.zig");

const lockfile_detectors = [_]struct {
    file: []const u8,
    manager: ManagerType,
}{
    .{ .file = "Cargo.toml", .manager = .cargo },
    .{ .file = "pnpm-lock.yaml", .manager = .pnpm },
    .{ .file = "bun.lock", .manager = .bun },
    .{ .file = "package-lock.json", .manager = .npm },
    .{ .file = "yarn.lock", .manager = .yarn },
    .{ .file = "uv.lock", .manager = .uv },
    .{ .file = "poetry.lock", .manager = .poetry },
    .{ .file = "pdm.lock", .manager = .pdm },
    .{ .file = "requirements.txt", .manager = .pip },
};

const node_lockfile_detectors = [_]struct {
    file: []const u8,
    manager: ManagerType,
}{
    .{ .file = "pnpm-lock.yaml", .manager = .pnpm },
    .{ .file = "bun.lock", .manager = .bun },
    .{ .file = "package-lock.json", .manager = .npm },
    .{ .file = "yarn.lock", .manager = .yarn },
};

const PackageJsonDocument = struct {
    content: []u8,
    parsed: std.json.Parsed(std.json.Value),

    fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        self.parsed.deinit();
        allocator.free(self.content);
    }

    fn rootObject(self: *const @This()) ?std.json.ObjectMap {
        return switch (self.parsed.value) {
            .object => |object| object,
            else => null,
        };
    }
};

const DetectionStrength = enum {
    strong,
    weak_node_fallback,
};

const DetectionResult = struct {
    manager: ManagerType,
    strength: DetectionStrength,
};

/// Detects the current package manager type by checking for lock files.
///
/// This function scans the current working directory for known package manager
/// lock files in priority order. The first found determines file the package manager.
///
/// Detection Priority (lower number = higher priority):
///   0 - Cargo.toml (Rust/Cargo)
///   1 - pnpm-lock.yaml (pnpm)
///   2 - bun.lock (Bun)
///   3 - package-lock.json (npm)
///   4 - yarn.lock (Yarn)
///   5 - uv.lock (uv)
///   6 - poetry.lock (Poetry)
///   7 - pdm.lock (PDM)
///   8 - requirements.txt (pip - indicates Python project)
///   9 - pyproject.toml tool sections (uv/poetry/pdm)
///
/// Returns:
///   ManagerType if a supported package manager is detected, null otherwise
///
/// Example:
///   ```zig
///   const manager = detectPackageManager();
///   if (manager) |m| {
///       std.debug.print("Detected: {s}\n", .{@tagName(m)});
///   } else {
///       std.debug.print("No supported package manager found\n", .{});
///   }
/// ```
pub fn detectPackageManager() ?ManagerType {
    const rt = runtime.get();
    const current_dir = std.process.currentPathAlloc(rt.io, rt.allocator) catch return null;
    defer rt.allocator.free(current_dir);

    return detectPackageManagerFromPathWithRuntime(rt, current_dir);
}

pub fn detectPackageManagerFromPath(start_dir: []const u8) ?ManagerType {
    return detectPackageManagerFromPathWithRuntime(runtime.get(), start_dir);
}

pub fn detectPackageManagerFromPathWithRuntime(rt: *const runtime.Runtime, start_dir: []const u8) ?ManagerType {
    return detectPackageManagerFromPathWithPreferenceWithRuntime(rt, start_dir, null);
}

pub fn detectPackageManagerForCommand(
    action: []const u8,
    command_args: *const CommandArgs,
) ?ManagerType {
    const rt = runtime.get();
    const current_dir = std.process.currentPathAlloc(rt.io, rt.allocator) catch return null;
    defer rt.allocator.free(current_dir);

    return detectPackageManagerForCommandFromPathWithRuntime(rt, current_dir, action, command_args);
}

pub fn detectPackageManagerForCommandFromPath(
    start_dir: []const u8,
    action: []const u8,
    command_args: *const CommandArgs,
) ?ManagerType {
    return detectPackageManagerForCommandFromPathWithRuntime(runtime.get(), start_dir, action, command_args);
}

pub fn detectPackageManagerForCommandFromPathWithRuntime(
    rt: *const runtime.Runtime,
    start_dir: []const u8,
    action: []const u8,
    command_args: *const CommandArgs,
) ?ManagerType {
    return detectPackageManagerFromPathWithPreferenceWithRuntime(rt, start_dir, preferredRunTarget(action, command_args));
}

fn detectPackageManagerFromPathWithPreferenceWithRuntime(
    rt: *const runtime.Runtime,
    start_dir: []const u8,
    run_target: ?[]const u8,
) ?ManagerType {
    var current_dir = rt.allocator.dupeZ(u8, start_dir) catch return null;
    defer rt.allocator.free(current_dir);
    var weak_run_node_fallback: ?ManagerType = null;
    var weak_node_fallback: ?ManagerType = null;

    while (true) {
        if (run_target) |target| {
            if (detectNodeRunManagerDetailsInDirWithRuntime(rt, current_dir, target)) |detected| {
                switch (detected.strength) {
                    .strong => return detected.manager,
                    .weak_node_fallback => {
                        if (weak_run_node_fallback == null) {
                            weak_run_node_fallback = detected.manager;
                        }
                    },
                }
            }
        }

        if (detectInDirDetailedWithRuntime(rt, current_dir)) |detected| {
            switch (detected.strength) {
                .strong => {
                    if (weak_run_node_fallback != null) {
                        if (isNodeManager(detected.manager)) {
                            return detected.manager;
                        }
                        return weak_run_node_fallback;
                    }
                    if (weak_node_fallback != null and !isNodeManager(detected.manager)) {
                        return weak_node_fallback;
                    }
                    return detected.manager;
                },
                .weak_node_fallback => {
                    if (weak_node_fallback == null) {
                        weak_node_fallback = detected.manager;
                    }
                },
            }
        }

        const parent = std.fs.path.dirname(current_dir) orelse return weak_run_node_fallback orelse weak_node_fallback;
        if (std.mem.eql(u8, parent, current_dir)) return weak_run_node_fallback orelse weak_node_fallback;

        const parent_copy = rt.allocator.dupeZ(u8, parent) catch return null;
        rt.allocator.free(current_dir);
        current_dir = parent_copy;
    }
}

fn preferredRunTarget(action: []const u8, command_args: *const CommandArgs) ?[]const u8 {
    if (actionEq(action, "run")) {
        return firstNonEmpty(command_args.packages.items);
    }

    if (actionEq(action, "exec")) {
        const manager_args = command_args.manager_args.items;
        if (manager_args.len >= 2 and actionEq(manager_args[0], "run")) {
            return manager_args[1];
        }
    }

    return null;
}

fn firstNonEmpty(values: []const []const u8) ?[]const u8 {
    for (values) |value| {
        if (value.len != 0) return value;
    }
    return null;
}

fn actionEq(value: []const u8, expected: []const u8) bool {
    return std.ascii.eqlIgnoreCase(value, expected);
}

fn detectInDir(dir_path: []const u8) ?ManagerType {
    return detectInDirWithRuntime(runtime.get(), dir_path);
}

fn detectInDirWithRuntime(rt: *const runtime.Runtime, dir_path: []const u8) ?ManagerType {
    const detected = detectInDirDetailedWithRuntime(rt, dir_path) orelse return null;
    return detected.manager;
}

fn detectInDirDetailedWithRuntime(rt: *const runtime.Runtime, dir_path: []const u8) ?DetectionResult {
    for (lockfile_detectors) |detector| {
        if (pathExists(rt, dir_path, detector.file)) {
            return .{
                .manager = detector.manager,
                .strength = .strong,
            };
        }
    }

    if (pathExists(rt, dir_path, "pyproject.toml")) {
        const pyproject = readFileFromDir(rt, dir_path, "pyproject.toml") orelse return null;
        defer rt.allocator.free(pyproject);

        if (hasTomlSection(pyproject, "tool.poetry")) return .{
            .manager = .poetry,
            .strength = .strong,
        };
        if (hasTomlSection(pyproject, "tool.pdm")) return .{
            .manager = .pdm,
            .strength = .strong,
        };
        if (hasTomlSection(pyproject, "tool.uv")) return .{
            .manager = .uv,
            .strength = .strong,
        };
    }

    return detectNodeManagerFallbackDetailsInDirWithRuntime(rt, dir_path);
}

fn detectNodeRunManagerInDirWithRuntime(
    rt: *const runtime.Runtime,
    dir_path: []const u8,
    run_target: []const u8,
) ?ManagerType {
    const detected = detectNodeRunManagerDetailsInDirWithRuntime(rt, dir_path, run_target) orelse return null;
    return detected.manager;
}

fn detectNodeRunManagerDetailsInDirWithRuntime(
    rt: *const runtime.Runtime,
    dir_path: []const u8,
    run_target: []const u8,
) ?DetectionResult {
    var package_json = loadPackageJsonFromDirWithRuntime(rt, dir_path) orelse return null;
    defer package_json.deinit(rt.allocator);

    const root = package_json.rootObject() orelse return null;

    if (!jsonObjectHasKey(root.get("scripts"), run_target)) return null;

    if (detectNodeLockfileManagerInDirWithRuntime(rt, dir_path)) |manager| {
        return .{
            .manager = manager,
            .strength = .strong,
        };
    }

    if (nodeManagerFromPackageJsonRoot(root)) |manager| {
        return .{
            .manager = manager,
            .strength = .strong,
        };
    }

    return .{
        .manager = .npm,
        .strength = .weak_node_fallback,
    };
}

fn detectNodeManagerFallbackInDirWithRuntime(rt: *const runtime.Runtime, dir_path: []const u8) ?ManagerType {
    const detected = detectNodeManagerFallbackDetailsInDirWithRuntime(rt, dir_path) orelse return null;
    return detected.manager;
}

fn detectNodeManagerFallbackDetailsInDirWithRuntime(
    rt: *const runtime.Runtime,
    dir_path: []const u8,
) ?DetectionResult {
    var package_json = loadPackageJsonFromDirWithRuntime(rt, dir_path) orelse return null;
    defer package_json.deinit(rt.allocator);

    const root = package_json.rootObject() orelse return null;

    if (root.get("packageManager") != null) {
        const manager = nodeManagerFromPackageJsonRoot(root) orelse return null;
        return .{
            .manager = manager,
            .strength = .strong,
        };
    }

    return .{
        .manager = .npm,
        .strength = .weak_node_fallback,
    };
}

fn detectNodeLockfileManagerInDirWithRuntime(rt: *const runtime.Runtime, dir_path: []const u8) ?ManagerType {
    for (node_lockfile_detectors) |detector| {
        if (pathExists(rt, dir_path, detector.file)) {
            return detector.manager;
        }
    }
    return null;
}

fn jsonObjectHasKey(value: ?std.json.Value, key: []const u8) bool {
    const json_value = value orelse return false;
    return switch (json_value) {
        .object => |object| object.get(key) != null,
        else => false,
    };
}

fn nodeManagerFromPackageJsonRoot(root: std.json.ObjectMap) ?ManagerType {
    return nodeManagerFromPackageManagerField(root.get("packageManager"));
}

fn nodeManagerFromPackageManagerField(value: ?std.json.Value) ?ManagerType {
    const json_value = value orelse return null;
    const package_manager = switch (json_value) {
        .string => |name| name,
        else => return null,
    };

    if (packageManagerNameMatches(package_manager, "pnpm")) return .pnpm;
    if (packageManagerNameMatches(package_manager, "bun")) return .bun;
    if (packageManagerNameMatches(package_manager, "npm")) return .npm;
    if (packageManagerNameMatches(package_manager, "yarn")) return .yarn;
    return null;
}

fn packageManagerNameMatches(value: []const u8, expected: []const u8) bool {
    if (std.ascii.eqlIgnoreCase(value, expected)) return true;
    if (value.len <= expected.len or value[expected.len] != '@') return false;
    return std.ascii.eqlIgnoreCase(value[0..expected.len], expected);
}

fn isNodeManager(manager: ManagerType) bool {
    return switch (manager) {
        .npm, .pnpm, .bun, .yarn => true,
        else => false,
    };
}

fn loadPackageJsonFromDirWithRuntime(rt: *const runtime.Runtime, dir_path: []const u8) ?PackageJsonDocument {
    const package_json = readFileFromDir(rt, dir_path, "package.json") orelse return null;
    const parsed = std.json.parseFromSlice(std.json.Value, rt.allocator, package_json, .{}) catch {
        rt.allocator.free(package_json);
        return null;
    };

    return .{
        .content = package_json,
        .parsed = parsed,
    };
}

fn pathExists(rt: *const runtime.Runtime, dir_path: []const u8, file_name: []const u8) bool {
    const full_path = std.fs.path.join(rt.allocator, &.{ dir_path, file_name }) catch return false;
    defer rt.allocator.free(full_path);

    std.Io.Dir.cwd().access(rt.io, full_path, .{}) catch return false;
    return true;
}

fn readFileFromDir(rt: *const runtime.Runtime, dir_path: []const u8, file_name: []const u8) ?[]u8 {
    const full_path = std.fs.path.join(rt.allocator, &.{ dir_path, file_name }) catch return null;
    defer rt.allocator.free(full_path);

    const file = std.Io.Dir.cwd().openFile(rt.io, full_path, .{}) catch return null;
    defer file.close(rt.io);

    var read_buf: [4096]u8 = undefined;
    var reader = file.reader(rt.io, &read_buf);
    return reader.interface.allocRemaining(rt.allocator, .limited(128 * 1024)) catch null;
}

fn hasTomlSection(content: []const u8, section_name: []const u8) bool {
    var pattern_buf: [64]u8 = undefined;
    const exact = std.fmt.bufPrint(&pattern_buf, "[{s}]", .{section_name}) catch return false;
    if (std.mem.indexOf(u8, content, exact) != null) return true;

    const nested = std.fmt.bufPrint(&pattern_buf, "[{s}.", .{section_name}) catch return false;
    return std.mem.indexOf(u8, content, nested) != null;
}

fn testRuntime(environ_map: *std.process.Environ.Map) runtime.Runtime {
    return .{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = environ_map,
    };
}

fn tmpDirPath(allocator: std.mem.Allocator, tmp: *std.testing.TmpDir) ![]u8 {
    return std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}", .{tmp.sub_path});
}

fn expectDetectedLockfile(file_name: []const u8, file_data: []const u8, expected: ManagerType) !void {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt = testRuntime(&environ_map);
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const dir_path = try tmpDirPath(std.testing.allocator, &tmp);
    defer std.testing.allocator.free(dir_path);

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = file_name,
        .data = file_data,
    });

    const manager = detectInDirWithRuntime(&rt, dir_path);
    try std.testing.expect(manager != null);
    try std.testing.expectEqual(expected, manager.?);
}

fn expectDetectedPackageJson(file_data: []const u8, expected: ?ManagerType) !void {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt = testRuntime(&environ_map);
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const dir_path = try tmpDirPath(std.testing.allocator, &tmp);
    defer std.testing.allocator.free(dir_path);

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "package.json",
        .data = file_data,
    });

    try std.testing.expectEqual(expected, detectInDirWithRuntime(&rt, dir_path));
}

test "detects managers from non-python lockfiles" {
    try expectDetectedLockfile("Cargo.toml", "[package]\nname = \"demo\"\nversion = \"0.1.0\"\n", .cargo);
    try expectDetectedLockfile("pnpm-lock.yaml", "lockfileVersion: '9.0'\n", .pnpm);
    try expectDetectedLockfile("bun.lock", "lockfileVersion 1\n", .bun);
    try expectDetectedLockfile("package-lock.json", "{\n  \"name\": \"demo\"\n}\n", .npm);
    try expectDetectedLockfile("yarn.lock", "__metadata:\n  version: 8\n", .yarn);
    try expectDetectedLockfile("requirements.txt", "requests==2.32.0\n", .pip);
}

test "detects uv from uv.lock" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt = testRuntime(&environ_map);
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const dir_path = try tmpDirPath(std.testing.allocator, &tmp);
    defer std.testing.allocator.free(dir_path);

    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "uv.lock", .data = "version = 1\n" });

    const manager = detectInDirWithRuntime(&rt, dir_path);
    try std.testing.expect(manager != null);
    try std.testing.expectEqual(ManagerType.uv, manager.?);
}

test "detects poetry lock before requirements.txt" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt = testRuntime(&environ_map);
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const dir_path = try tmpDirPath(std.testing.allocator, &tmp);
    defer std.testing.allocator.free(dir_path);

    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "requirements.txt", .data = "requests\n" });
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "poetry.lock", .data = "[[package]]\nname = \"demo\"\n" });

    const manager = detectInDirWithRuntime(&rt, dir_path);
    try std.testing.expect(manager != null);
    try std.testing.expectEqual(ManagerType.poetry, manager.?);
}

test "detects pdm from pdm.lock" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt = testRuntime(&environ_map);
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const dir_path = try tmpDirPath(std.testing.allocator, &tmp);
    defer std.testing.allocator.free(dir_path);

    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "pdm.lock", .data = "[metadata]\nlock_version = \"4.0\"\n" });

    const manager = detectInDirWithRuntime(&rt, dir_path);
    try std.testing.expect(manager != null);
    try std.testing.expectEqual(ManagerType.pdm, manager.?);
}

test "detects managers from pyproject tool sections" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt = testRuntime(&environ_map);

    {
        var tmp = std.testing.tmpDir(.{});
        defer tmp.cleanup();

        const dir_path = try tmpDirPath(std.testing.allocator, &tmp);
        defer std.testing.allocator.free(dir_path);

        try tmp.dir.writeFile(std.testing.io, .{
            .sub_path = "pyproject.toml",
            .data =
            \\[project]
            \\name = "demo"
            \\version = "0.1.0"
            \\
            \\[tool.uv]
            \\package = true
            ,
        });

        const manager = detectInDirWithRuntime(&rt, dir_path);
        try std.testing.expect(manager != null);
        try std.testing.expectEqual(ManagerType.uv, manager.?);
    }

    {
        var tmp = std.testing.tmpDir(.{});
        defer tmp.cleanup();

        const dir_path = try tmpDirPath(std.testing.allocator, &tmp);
        defer std.testing.allocator.free(dir_path);

        try tmp.dir.writeFile(std.testing.io, .{
            .sub_path = "pyproject.toml",
            .data =
            \\[tool.poetry]
            \\name = "demo"
            \\version = "0.1.0"
            \\description = ""
            \\authors = ["dev <dev@example.com>"]
            ,
        });

        const manager = detectInDirWithRuntime(&rt, dir_path);
        try std.testing.expect(manager != null);
        try std.testing.expectEqual(ManagerType.poetry, manager.?);
    }

    {
        var tmp = std.testing.tmpDir(.{});
        defer tmp.cleanup();

        const dir_path = try tmpDirPath(std.testing.allocator, &tmp);
        defer std.testing.allocator.free(dir_path);

        try tmp.dir.writeFile(std.testing.io, .{
            .sub_path = "pyproject.toml",
            .data =
            \\[project]
            \\name = "demo"
            \\version = "0.1.0"
            \\
            \\[tool.pdm]
            \\distribution = true
            ,
        });

        const manager = detectInDirWithRuntime(&rt, dir_path);
        try std.testing.expect(manager != null);
        try std.testing.expectEqual(ManagerType.pdm, manager.?);
    }
}

test "plain pyproject does not default to poetry" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt = testRuntime(&environ_map);
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const dir_path = try tmpDirPath(std.testing.allocator, &tmp);
    defer std.testing.allocator.free(dir_path);

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "pyproject.toml",
        .data =
        \\[project]
        \\name = "demo"
        \\version = "0.1.0"
        ,
    });

    try std.testing.expectEqual(@as(?ManagerType, null), detectInDirWithRuntime(&rt, dir_path));
}

test "detects node manager from packageManager without lockfile" {
    try expectDetectedPackageJson(
        \\{
        \\  "name": "demo",
        \\  "packageManager": "pnpm@9.12.0"
        \\}
        ,
        .pnpm,
    );
    try expectDetectedPackageJson(
        \\{
        \\  "name": "demo",
        \\  "packageManager": "yarn@4.6.0"
        \\}
        ,
        .yarn,
    );
    try expectDetectedPackageJson(
        \\{
        \\  "name": "demo",
        \\  "packageManager": "bun@1.1.0"
        \\}
        ,
        .bun,
    );
    try expectDetectedPackageJson(
        \\{
        \\  "name": "demo",
        \\  "packageManager": "npm@10.8.2"
        \\}
        ,
        .npm,
    );
}

test "plain package.json falls back to npm" {
    try expectDetectedPackageJson(
        \\{
        \\  "name": "demo",
        \\  "version": "1.0.0"
        \\}
        ,
        .npm,
    );
}

test "pyproject tool section still wins over package.json fallback" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt = testRuntime(&environ_map);
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const dir_path = try tmpDirPath(std.testing.allocator, &tmp);
    defer std.testing.allocator.free(dir_path);

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "pyproject.toml",
        .data =
        \\[project]
        \\name = "demo"
        \\version = "0.1.0"
        \\
        \\[tool.uv]
        \\package = true
        ,
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "package.json",
        .data =
        \\{
        \\  "name": "demo",
        \\  "packageManager": "pnpm@9.12.0"
        \\}
        ,
    });

    const manager = detectInDirWithRuntime(&rt, dir_path);
    try std.testing.expect(manager != null);
    try std.testing.expectEqual(ManagerType.uv, manager.?);
}

test "detects manager by walking up to parent directory" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt = testRuntime(&environ_map);
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var workspace_dir = try tmp.dir.createDirPathOpen(std.testing.io, "workspace/packages/app", .{});
    workspace_dir.close(std.testing.io);

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "workspace/poetry.lock",
        .data = "[[package]]\nname = \"demo\"\n",
    });

    const nested_path = try std.fmt.allocPrint(
        std.testing.allocator,
        ".zig-cache/tmp/{s}/workspace/packages/app",
        .{tmp.sub_path},
    );
    defer std.testing.allocator.free(nested_path);

    const manager = detectPackageManagerFromPathWithRuntime(&rt, nested_path);
    try std.testing.expect(manager != null);
    try std.testing.expectEqual(ManagerType.poetry, manager.?);
}

test "detects parent pnpm workspace over child plain package json" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt = testRuntime(&environ_map);
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

    const nested_path = try std.fmt.allocPrint(
        std.testing.allocator,
        ".zig-cache/tmp/{s}/workspace/packages/app",
        .{tmp.sub_path},
    );
    defer std.testing.allocator.free(nested_path);

    const manager = detectPackageManagerFromPathWithRuntime(&rt, nested_path);
    try std.testing.expect(manager != null);
    try std.testing.expectEqual(ManagerType.pnpm, manager.?);
}

test "detect keeps child plain package json over parent cargo root" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt = testRuntime(&environ_map);
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

    const nested_path = try std.fmt.allocPrint(
        std.testing.allocator,
        ".zig-cache/tmp/{s}/workspace/apps/web",
        .{tmp.sub_path},
    );
    defer std.testing.allocator.free(nested_path);

    const manager = detectPackageManagerFromPathWithRuntime(&rt, nested_path);
    try std.testing.expect(manager != null);
    try std.testing.expectEqual(ManagerType.npm, manager.?);
}

test "run upgrades child package script to parent pnpm workspace manager" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt = testRuntime(&environ_map);
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

    const nested_path = try std.fmt.allocPrint(
        std.testing.allocator,
        ".zig-cache/tmp/{s}/workspace/packages/app",
        .{tmp.sub_path},
    );
    defer std.testing.allocator.free(nested_path);

    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();
    try command_args.addPackage("build");

    const manager = detectPackageManagerForCommandFromPathWithRuntime(&rt, nested_path, "run", &command_args);
    try std.testing.expect(manager != null);
    try std.testing.expectEqual(ManagerType.pnpm, manager.?);
}

test "run keeps child package script over parent cargo root" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt = testRuntime(&environ_map);
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
        \\  "scripts": {
        \\    "build": "node build.js"
        \\  }
        \\}
        ,
    });

    const nested_path = try std.fmt.allocPrint(
        std.testing.allocator,
        ".zig-cache/tmp/{s}/workspace/apps/web",
        .{tmp.sub_path},
    );
    defer std.testing.allocator.free(nested_path);

    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();
    try command_args.addPackage("build");

    const manager = detectPackageManagerForCommandFromPathWithRuntime(&rt, nested_path, "run", &command_args);
    try std.testing.expect(manager != null);
    try std.testing.expectEqual(ManagerType.npm, manager.?);
}

test "run prefers node script target over cargo in mixed repository" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt = testRuntime(&environ_map);
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const dir_path = try tmpDirPath(std.testing.allocator, &tmp);
    defer std.testing.allocator.free(dir_path);

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

    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();
    try command_args.addPackage("build:apk");

    const manager = detectPackageManagerForCommandFromPathWithRuntime(&rt, dir_path, "run", &command_args);
    try std.testing.expect(manager != null);
    try std.testing.expectEqual(ManagerType.npm, manager.?);
}

test "run falls back to cargo when package script target is absent" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt = testRuntime(&environ_map);
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const dir_path = try tmpDirPath(std.testing.allocator, &tmp);
    defer std.testing.allocator.free(dir_path);

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "Cargo.toml",
        .data =
        \\[package]
        \\name = "demo"
        \\version = "0.1.0"
        ,
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "package.json",
        .data =
        \\{
        \\  "name": "demo",
        \\  "scripts": {
        \\    "test": "echo test"
        \\  }
        \\}
        ,
    });

    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();
    try command_args.addPackage("build:apk");

    const manager = detectPackageManagerForCommandFromPathWithRuntime(&rt, dir_path, "run", &command_args);
    try std.testing.expect(manager != null);
    try std.testing.expectEqual(ManagerType.cargo, manager.?);
}

test "exec run also prefers package manager declared by package.json" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();

    const rt = testRuntime(&environ_map);
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const dir_path = try tmpDirPath(std.testing.allocator, &tmp);
    defer std.testing.allocator.free(dir_path);

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "Cargo.toml",
        .data =
        \\[package]
        \\name = "demo"
        \\version = "0.1.0"
        ,
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "package.json",
        .data =
        \\{
        \\  "name": "demo",
        \\  "packageManager": "pnpm@9.12.0",
        \\  "scripts": {
        \\    "build": "echo build"
        \\  }
        \\}
        ,
    });

    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();
    try command_args.addManagerArg("run");
    try command_args.addManagerArg("build");

    const manager = detectPackageManagerForCommandFromPathWithRuntime(&rt, dir_path, "exec", &command_args);
    try std.testing.expect(manager != null);
    try std.testing.expectEqual(ManagerType.pnpm, manager.?);
}
