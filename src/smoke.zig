const builtin = @import("builtin");
const std = @import("std");

const FileSpec = struct {
    path: []const u8,
    data: []const u8,
};

const ScenarioSpec = struct {
    name: []const u8,
    manager_name: []const u8,
    mg_args: []const []const u8,
    files: []const FileSpec,
    start_dir: ?[]const u8 = null,
    expected_marker: ?[]const u8 = null,
    expected_preview: ?[]const u8 = null,
    expected_generated_path: ?[]const u8 = null,
};

const cargo_files = [_]FileSpec{
    .{
        .path = "Cargo.toml",
        .data =
        \\[package]
        \\name = "mg-smoke-cargo"
        \\version = "0.1.0"
        \\edition = "2021"
        ,
    },
    .{
        .path = "src/main.rs",
        .data =
        \\fn main() {
        \\    println!("mg-smoke-cargo");
        \\}
        ,
    },
    .{
        .path = "src/lib.rs",
        .data =
        \\#[cfg(test)]
        \\mod tests {
        \\    #[test]
        \\    fn smoke_test() {
        \\        println!("mg-smoke-cargo-test");
        \\        assert_eq!(2 + 2, 4);
        \\    }
        \\}
        ,
    },
};

const npm_files = [_]FileSpec{
    .{
        .path = "package.json",
        .data =
        \\{
        \\  "name": "mg-smoke-npm",
        \\  "version": "0.0.0",
        \\  "scripts": {
        \\    "smoke": "node smoke.js"
        \\  }
        \\}
        ,
    },
    .{
        .path = "package-lock.json",
        .data =
        \\{
        \\  "name": "mg-smoke-npm",
        \\  "lockfileVersion": 3,
        \\  "packages": {}
        \\}
        ,
    },
    .{
        .path = "smoke.js",
        .data =
        \\console.log("mg-smoke-npm");
        ,
    },
};

const npm_package_json_only_files = [_]FileSpec{
    .{
        .path = "package.json",
        .data =
        \\{
        \\  "name": "mg-smoke-npm-fallback",
        \\  "version": "0.0.0"
        \\}
        ,
    },
};

const pnpm_files = [_]FileSpec{
    .{
        .path = "package.json",
        .data =
        \\{
        \\  "name": "mg-smoke-pnpm",
        \\  "version": "0.0.0",
        \\  "scripts": {
        \\    "smoke": "node smoke.js"
        \\  }
        \\}
        ,
    },
    .{
        .path = "pnpm-lock.yaml",
        .data =
        \\lockfileVersion: '9.0'
        ,
    },
    .{
        .path = "smoke.js",
        .data =
        \\console.log("mg-smoke-pnpm");
        ,
    },
};

const pnpm_package_manager_files = [_]FileSpec{
    .{
        .path = "package.json",
        .data =
        \\{
        \\  "name": "mg-smoke-pnpm-package-manager",
        \\  "version": "0.0.0",
        \\  "packageManager": "pnpm@9.12.0"
        \\}
        ,
    },
};

const pnpm_workspace_child_files = [_]FileSpec{
    .{
        .path = "package.json",
        .data =
        \\{
        \\  "name": "mg-smoke-pnpm-workspace",
        \\  "private": true,
        \\  "packageManager": "pnpm@9.12.0"
        \\}
        ,
    },
    .{
        .path = "packages/app/package.json",
        .data =
        \\{
        \\  "name": "mg-smoke-pnpm-workspace-app",
        \\  "version": "0.0.0",
        \\  "scripts": {
        \\    "smoke": "node smoke.js"
        \\  }
        \\}
        ,
    },
    .{
        .path = "packages/app/smoke.js",
        .data =
        \\console.log("mg-smoke-pnpm-workspace-child");
        ,
    },
};

const cargo_root_with_child_package_files = [_]FileSpec{
    .{
        .path = "Cargo.toml",
        .data =
        \\[package]
        \\name = "mg-smoke-cargo-root"
        \\version = "0.1.0"
        \\edition = "2021"
        ,
    },
    .{
        .path = "src/main.rs",
        .data =
        \\fn main() {
        \\    println!("mg-smoke-cargo-root");
        \\}
        ,
    },
    .{
        .path = "apps/web/package.json",
        .data =
        \\{
        \\  "name": "mg-smoke-web",
        \\  "version": "0.0.0"
        \\}
        ,
    },
};

const bun_files = [_]FileSpec{
    .{
        .path = "package.json",
        .data =
        \\{
        \\  "name": "mg-smoke-bun",
        \\  "version": "0.0.0",
        \\  "scripts": {
        \\    "smoke": "bun smoke.js"
        \\  }
        \\}
        ,
    },
    .{
        .path = "bun.lock",
        .data =
        \\lockfileVersion 1
        ,
    },
    .{
        .path = "smoke.js",
        .data =
        \\console.log("mg-smoke-bun");
        ,
    },
    .{
        .path = "smoke.test.ts",
        .data =
        \\import { expect, test } from "bun:test";
        \\
        \\test("smoke", () => {
        \\    console.log("mg-smoke-bun-test");
        \\    expect(2 + 2).toBe(4);
        \\});
        ,
    },
};

const yarn_files = [_]FileSpec{
    .{
        .path = "package.json",
        .data =
        \\{
        \\  "name": "mg-smoke-yarn",
        \\  "version": "0.0.0",
        \\  "scripts": {
        \\    "smoke": "node smoke.js"
        \\  }
        \\}
        ,
    },
    .{
        .path = "yarn.lock",
        .data =
        \\# yarn lockfile v1
        ,
    },
    .{
        .path = "smoke.js",
        .data =
        \\console.log("mg-smoke-yarn");
        ,
    },
};

const uv_files = [_]FileSpec{
    .{
        .path = "pyproject.toml",
        .data =
        \\[project]
        \\name = "mg-smoke-uv"
        \\version = "0.1.0"
        \\
        \\[tool.uv]
        \\package = false
        ,
    },
};

const pip_files = [_]FileSpec{
    .{
        .path = "requirements.txt",
        .data =
        \\requests==2.32.0
        ,
    },
};

const poetry_files = [_]FileSpec{
    .{
        .path = "pyproject.toml",
        .data =
        \\[tool.poetry]
        \\name = "mg-smoke-poetry"
        \\version = "0.1.0"
        \\description = ""
        \\authors = ["mg <mg@example.com>"]
        \\
        \\[tool.poetry.dependencies]
        \\python = ">=3.10,<4.0"
        ,
    },
    .{
        .path = "poetry.lock",
        .data =
        \\[[package]]
        \\name = "demo"
        \\version = "0.1.0"
        ,
    },
    .{
        .path = "smoke.py",
        .data =
        \\print("mg-smoke-poetry")
        ,
    },
};

const pdm_files = [_]FileSpec{
    .{
        .path = "pyproject.toml",
        .data =
        \\[project]
        \\name = "mg-smoke-pdm"
        \\version = "0.1.0"
        \\requires-python = ">=3.10"
        \\
        \\[tool.pdm]
        \\distribution = false
        ,
    },
    .{
        .path = "pdm.lock",
        .data =
        \\[metadata]
        \\lock_version = "4.0"
        ,
    },
    .{
        .path = "smoke.py",
        .data =
        \\print("mg-smoke-pdm")
        ,
    },
};

const pdm_scripts_files = [_]FileSpec{
    .{
        .path = "pyproject.toml",
        .data =
        \\[project]
        \\name = "mg-smoke-pdm-scripts"
        \\version = "0.1.0"
        \\requires-python = ">=3.10"
        \\
        \\[tool.pdm]
        \\distribution = false
        \\
        \\[tool.pdm.scripts]
        \\smoke = "python smoke.py"
        ,
    },
    .{
        .path = "smoke.py",
        .data =
        \\print("mg-smoke-pdm-script")
        ,
    },
};

const cargo_args = [_][]const u8{ "run", "smoke" };
const npm_args = [_][]const u8{ "run", "smoke" };
const pnpm_args = [_][]const u8{ "run", "smoke" };
const bun_args = [_][]const u8{ "run", "smoke" };
const yarn_args = [_][]const u8{ "run", "smoke" };
const uv_args = [_][]const u8{ "run", "python", "--", "-c", "print('mg-smoke-uv')" };
const exec_version_args = [_][]const u8{ "exec", "--", "--version" };
const cargo_exec_test_args = [_][]const u8{ "exec", "--", "test", "--", "--nocapture" };
const cargo_exec_check_args = [_][]const u8{ "exec", "--", "check" };
const cargo_exec_metadata_args = [_][]const u8{ "exec", "--", "metadata", "--no-deps" };
const npm_exec_list_args = [_][]const u8{ "exec", "--", "list" };
const npm_exec_run_args = [_][]const u8{ "exec", "--", "run", "smoke" };
const npm_exec_node_args = [_][]const u8{ "exec", "--", "exec", "--", "node", "smoke.js" };
const pnpm_exec_list_args = [_][]const u8{ "exec", "--", "list" };
const pnpm_exec_run_args = [_][]const u8{ "exec", "--", "run", "smoke" };
const pnpm_exec_node_args = [_][]const u8{ "exec", "--", "exec", "node", "smoke.js" };
const bun_exec_test_args = [_][]const u8{ "exec", "--", "test" };
const bun_exec_run_args = [_][]const u8{ "exec", "--", "run", "smoke" };
const yarn_exec_list_args = [_][]const u8{ "exec", "--", "list" };
const yarn_exec_run_args = [_][]const u8{ "exec", "--", "run", "smoke" };
const uv_exec_sync_args = [_][]const u8{ "exec", "--", "sync" };
const uv_exec_tree_args = [_][]const u8{ "exec", "--", "tree" };
const uv_exec_lock_args = [_][]const u8{ "exec", "--", "lock" };
const uv_exec_run_args = [_][]const u8{ "exec", "--", "run", "python", "-c", "print('mg-smoke-uv')" };
const poetry_exec_check_args = [_][]const u8{ "exec", "--", "check" };
const poetry_exec_show_args = [_][]const u8{ "exec", "--", "show" };
const poetry_exec_run_args = [_][]const u8{ "exec", "--", "run", "python", "smoke.py" };
const pdm_exec_list_args = [_][]const u8{ "exec", "--", "list" };
const pdm_exec_run_list_args = [_][]const u8{ "exec", "--", "run", "--list" };
const pdm_exec_script_shortcut_args = [_][]const u8{ "exec", "--", "smoke" };
const pdm_exec_run_args = [_][]const u8{ "exec", "--", "run", "python", "smoke.py" };
const poetry_run_args = [_][]const u8{ "run", "python", "smoke.py" };
const pdm_run_args = [_][]const u8{ "run", "python", "smoke.py" };
const uv_install_profiles_dry_run_args = [_][]const u8{ "-d", "install", "-D", "-P", "docs", "-P", "lint" };
const poetry_install_profiles_dry_run_args = [_][]const u8{ "-d", "install", "-D", "-P", "docs", "-P", "lint" };
const pdm_list_profiles_dry_run_args = [_][]const u8{ "-d", "list", "-D", "-P", "docs", "-P", "lint" };
const install_dry_run_args = [_][]const u8{ "-d", "install" };

const scenarios = [_]ScenarioSpec{
    .{
        .name = "cargo_run",
        .manager_name = "cargo",
        .mg_args = &cargo_args,
        .files = &cargo_files,
        .expected_marker = "mg-smoke-cargo",
    },
    .{
        .name = "cargo_exec_version",
        .manager_name = "cargo",
        .mg_args = &exec_version_args,
        .files = &cargo_files,
    },
    .{
        .name = "cargo_exec_test",
        .manager_name = "cargo",
        .mg_args = &cargo_exec_test_args,
        .files = &cargo_files,
        .expected_marker = "mg-smoke-cargo-test",
    },
    .{
        .name = "cargo_exec_check",
        .manager_name = "cargo",
        .mg_args = &cargo_exec_check_args,
        .files = &cargo_files,
        .expected_generated_path = "target",
    },
    .{
        .name = "cargo_exec_metadata",
        .manager_name = "cargo",
        .mg_args = &cargo_exec_metadata_args,
        .files = &cargo_files,
    },
    .{
        .name = "npm_run",
        .manager_name = "npm",
        .mg_args = &npm_args,
        .files = &npm_files,
        .expected_marker = "mg-smoke-npm",
    },
    .{
        .name = "npm_package_json_install_dry_run",
        .manager_name = "npm",
        .mg_args = &install_dry_run_args,
        .files = &npm_package_json_only_files,
        .expected_preview = "npm install",
    },
    .{
        .name = "npm_exec_version",
        .manager_name = "npm",
        .mg_args = &exec_version_args,
        .files = &npm_files,
    },
    .{
        .name = "npm_exec_list",
        .manager_name = "npm",
        .mg_args = &npm_exec_list_args,
        .files = &npm_files,
        .expected_marker = "mg-smoke-npm",
    },
    .{
        .name = "npm_exec_run",
        .manager_name = "npm",
        .mg_args = &npm_exec_run_args,
        .files = &npm_files,
        .expected_marker = "mg-smoke-npm",
    },
    .{
        .name = "npm_exec_node",
        .manager_name = "npm",
        .mg_args = &npm_exec_node_args,
        .files = &npm_files,
        .expected_marker = "mg-smoke-npm",
    },
    .{
        .name = "pnpm_run",
        .manager_name = "pnpm",
        .mg_args = &pnpm_args,
        .files = &pnpm_files,
        .expected_marker = "mg-smoke-pnpm",
    },
    .{
        .name = "pnpm_package_manager_install_dry_run",
        .manager_name = "pnpm",
        .mg_args = &install_dry_run_args,
        .files = &pnpm_package_manager_files,
        .expected_preview = "pnpm install",
    },
    .{
        .name = "pnpm_workspace_child_install_dry_run",
        .manager_name = "pnpm",
        .mg_args = &install_dry_run_args,
        .files = &pnpm_workspace_child_files,
        .start_dir = "packages/app",
        .expected_preview = "pnpm install",
    },
    .{
        .name = "pnpm_exec_version",
        .manager_name = "pnpm",
        .mg_args = &exec_version_args,
        .files = &pnpm_files,
    },
    .{
        .name = "pnpm_exec_list",
        .manager_name = "pnpm",
        .mg_args = &pnpm_exec_list_args,
        .files = &pnpm_files,
    },
    .{
        .name = "pnpm_exec_run",
        .manager_name = "pnpm",
        .mg_args = &pnpm_exec_run_args,
        .files = &pnpm_files,
        .expected_marker = "mg-smoke-pnpm",
    },
    .{
        .name = "pnpm_workspace_child_run",
        .manager_name = "pnpm",
        .mg_args = &pnpm_args,
        .files = &pnpm_workspace_child_files,
        .start_dir = "packages/app",
        .expected_marker = "mg-smoke-pnpm-workspace-child",
    },
    .{
        .name = "pnpm_exec_node",
        .manager_name = "pnpm",
        .mg_args = &pnpm_exec_node_args,
        .files = &pnpm_files,
        .expected_marker = "mg-smoke-pnpm",
    },
    .{
        .name = "npm_child_package_over_cargo_root_install_dry_run",
        .manager_name = "npm",
        .mg_args = &install_dry_run_args,
        .files = &cargo_root_with_child_package_files,
        .start_dir = "apps/web",
        .expected_preview = "npm install",
    },
    .{
        .name = "bun_run",
        .manager_name = "bun",
        .mg_args = &bun_args,
        .files = &bun_files,
        .expected_marker = "mg-smoke-bun",
    },
    .{
        .name = "bun_exec_version",
        .manager_name = "bun",
        .mg_args = &exec_version_args,
        .files = &bun_files,
    },
    .{
        .name = "bun_exec_test",
        .manager_name = "bun",
        .mg_args = &bun_exec_test_args,
        .files = &bun_files,
        .expected_marker = "mg-smoke-bun-test",
    },
    .{
        .name = "bun_exec_run",
        .manager_name = "bun",
        .mg_args = &bun_exec_run_args,
        .files = &bun_files,
        .expected_marker = "mg-smoke-bun",
    },
    .{
        .name = "yarn_run",
        .manager_name = "yarn",
        .mg_args = &yarn_args,
        .files = &yarn_files,
        .expected_marker = "mg-smoke-yarn",
    },
    .{
        .name = "yarn_exec_version",
        .manager_name = "yarn",
        .mg_args = &exec_version_args,
        .files = &yarn_files,
    },
    .{
        .name = "yarn_exec_list",
        .manager_name = "yarn",
        .mg_args = &yarn_exec_list_args,
        .files = &yarn_files,
    },
    .{
        .name = "yarn_exec_run",
        .manager_name = "yarn",
        .mg_args = &yarn_exec_run_args,
        .files = &yarn_files,
        .expected_marker = "mg-smoke-yarn",
    },
    .{
        .name = "uv_run",
        .manager_name = "uv",
        .mg_args = &uv_args,
        .files = &uv_files,
        .expected_marker = "mg-smoke-uv",
    },
    .{
        .name = "uv_exec_version",
        .manager_name = "uv",
        .mg_args = &exec_version_args,
        .files = &uv_files,
    },
    .{
        .name = "uv_exec_sync",
        .manager_name = "uv",
        .mg_args = &uv_exec_sync_args,
        .files = &uv_files,
        .expected_generated_path = ".venv",
    },
    .{
        .name = "uv_exec_tree",
        .manager_name = "uv",
        .mg_args = &uv_exec_tree_args,
        .files = &uv_files,
    },
    .{
        .name = "uv_exec_run",
        .manager_name = "uv",
        .mg_args = &uv_exec_run_args,
        .files = &uv_files,
        .expected_marker = "mg-smoke-uv",
    },
    .{
        .name = "uv_exec_lock",
        .manager_name = "uv",
        .mg_args = &uv_exec_lock_args,
        .files = &uv_files,
        .expected_generated_path = "uv.lock",
    },
    .{
        .name = "uv_install_profiles_dry_run",
        .manager_name = "uv",
        .mg_args = &uv_install_profiles_dry_run_args,
        .files = &uv_files,
        .expected_preview = "uv sync --group dev --group docs --group lint",
    },
    .{
        .name = "pip_exec_version",
        .manager_name = "pip",
        .mg_args = &exec_version_args,
        .files = &pip_files,
    },
    .{
        .name = "poetry_exec_version",
        .manager_name = "poetry",
        .mg_args = &exec_version_args,
        .files = &poetry_files,
    },
    .{
        .name = "poetry_exec_check",
        .manager_name = "poetry",
        .mg_args = &poetry_exec_check_args,
        .files = &poetry_files,
    },
    .{
        .name = "poetry_exec_show",
        .manager_name = "poetry",
        .mg_args = &poetry_exec_show_args,
        .files = &poetry_files,
    },
    .{
        .name = "poetry_exec_run",
        .manager_name = "poetry",
        .mg_args = &poetry_exec_run_args,
        .files = &poetry_files,
        .expected_marker = "mg-smoke-poetry",
    },
    .{
        .name = "poetry_run",
        .manager_name = "poetry",
        .mg_args = &poetry_run_args,
        .files = &poetry_files,
        .expected_marker = "mg-smoke-poetry",
    },
    .{
        .name = "poetry_install_profiles_dry_run",
        .manager_name = "poetry",
        .mg_args = &poetry_install_profiles_dry_run_args,
        .files = &poetry_files,
        .expected_preview = "poetry install --with dev --with docs --with lint",
    },
    .{
        .name = "pdm_exec_version",
        .manager_name = "pdm",
        .mg_args = &exec_version_args,
        .files = &pdm_files,
    },
    .{
        .name = "pdm_exec_list",
        .manager_name = "pdm",
        .mg_args = &pdm_exec_list_args,
        .files = &pdm_files,
    },
    .{
        .name = "pdm_exec_run_list",
        .manager_name = "pdm",
        .mg_args = &pdm_exec_run_list_args,
        .files = &pdm_scripts_files,
        .expected_marker = "smoke",
    },
    .{
        .name = "pdm_exec_script_shortcut",
        .manager_name = "pdm",
        .mg_args = &pdm_exec_script_shortcut_args,
        .files = &pdm_scripts_files,
        .expected_marker = "mg-smoke-pdm-script",
    },
    .{
        .name = "pdm_exec_run",
        .manager_name = "pdm",
        .mg_args = &pdm_exec_run_args,
        .files = &pdm_files,
        .expected_marker = "mg-smoke-pdm",
    },
    .{
        .name = "pdm_run",
        .manager_name = "pdm",
        .mg_args = &pdm_run_args,
        .files = &pdm_files,
        .expected_marker = "mg-smoke-pdm",
    },
    .{
        .name = "pdm_list_profiles_dry_run",
        .manager_name = "pdm",
        .mg_args = &pdm_list_profiles_dry_run_args,
        .files = &pdm_files,
        .expected_preview = "pdm list --dev --group docs --group lint",
    },
};

const ScenarioStatus = enum {
    pass,
    skip,
    fail,
};

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

fn freeArgs(allocator: std.mem.Allocator, args: []const [:0]u8) void {
    for (args) |arg| allocator.free(arg);
    allocator.free(args);
}

fn writeAll(io: std.Io, file: std.Io.File, bytes: []const u8) void {
    var writer_buf: [1024]u8 = undefined;
    var writer = file.writer(io, &writer_buf);
    writer.interface.writeAll(bytes) catch {};
    writer.interface.flush() catch {};
}

fn printFmt(io: std.Io, file: std.Io.File, comptime format: []const u8, args: anytype) void {
    var buf: [4096]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, format, args) catch return;
    writeAll(io, file, msg);
}

fn printUsage(io: std.Io) void {
    printFmt(io, std.Io.File.stdout(),
        "Usage: mg-smoke <path-to-mg> [scenario...]\n\nAvailable scenarios:\n",
        .{},
    );
    for (scenarios) |scenario| {
        printFmt(io, std.Io.File.stdout(), "  - {s}\n", .{scenario.name});
    }
}

fn scenarioExists(name: []const u8) bool {
    for (scenarios) |scenario| {
        if (std.mem.eql(u8, scenario.name, name)) return true;
    }
    return false;
}

fn validateFilters(io: std.Io, filters: []const [:0]u8) !void {
    for (filters) |filter| {
        if (scenarioExists(filter)) continue;

        printFmt(io, std.Io.File.stderr(), "Unknown smoke scenario: {s}\n", .{filter});
        printUsage(io);
        return error.InvalidScenario;
    }
}

fn scenarioSelected(name: []const u8, filters: []const [:0]u8) bool {
    if (filters.len == 0) return true;

    for (filters) |filter| {
        if (std.mem.eql(u8, filter, name)) return true;
    }
    return false;
}

fn trimWhitespace(bytes: []const u8) []const u8 {
    return std.mem.trim(u8, bytes, " \t\r\n");
}

fn firstNonEmptyLine(bytes: []const u8) ?[]const u8 {
    var iter = std.mem.tokenizeAny(u8, bytes, "\r\n");
    while (iter.next()) |line| {
        const trimmed = trimWhitespace(line);
        if (trimmed.len != 0) return trimmed;
    }
    return null;
}

fn containsAny(haystack_a: []const u8, haystack_b: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack_a, needle) != null or
        std.mem.indexOf(u8, haystack_b, needle) != null;
}

fn knownEnvironmentSkipReason(scenario: *const ScenarioSpec, stdout: []const u8, stderr: []const u8) ?[]const u8 {
    _ = stdout;

    if (std.mem.eql(u8, scenario.manager_name, "cargo")) {
        if (std.mem.indexOf(u8, stderr, "LNK1181") != null or
            std.mem.indexOf(u8, stderr, "dbghelp.lib") != null)
        {
            return "local Rust/MSVC linker environment is incomplete (missing dbghelp.lib)";
        }
    }

    return null;
}

fn appendAllStrings(out: *std.ArrayList([]const u8), allocator: std.mem.Allocator, values: []const []const u8) !void {
    for (values) |value| {
        try out.append(allocator, value);
    }
}

fn formatCommandPreview(allocator: std.mem.Allocator, argv: []const []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    for (argv, 0..) |arg, idx| {
        if (idx != 0) try out.append(allocator, ' ');
        try out.appendSlice(allocator, arg);
    }

    return try out.toOwnedSlice(allocator);
}

fn ensureParentDir(dir: std.Io.Dir, io: std.Io, file_path: []const u8) !void {
    const parent = std.fs.path.dirname(file_path) orelse return;
    try dir.createDirPath(io, parent);
}

fn prepareScenarioDir(io: std.Io, scenario_rel_path: []const u8, files: []const FileSpec) !void {
    const cwd = std.Io.Dir.cwd();

    cwd.access(io, scenario_rel_path, .{}) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
    if (cwd.access(io, scenario_rel_path, .{})) {
        try cwd.deleteTree(io, scenario_rel_path);
    } else |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    }

    var scenario_dir = try cwd.createDirPathOpen(io, scenario_rel_path, .{});
    defer scenario_dir.close(io);

    for (files) |file| {
        try ensureParentDir(scenario_dir, io, file.path);
        try scenario_dir.writeFile(io, .{
            .sub_path = file.path,
            .data = file.data,
        });
    }
}

const ProbeResult = struct {
    available: bool,
    detail: []const u8,
};

fn makeProbeDetail(allocator: std.mem.Allocator, bytes: []const u8, fallback: []const u8) ![]u8 {
    if (firstNonEmptyLine(bytes)) |line| {
        return try allocator.dupe(u8, line);
    }
    return try allocator.dupe(u8, fallback);
}

fn runLocator(
    allocator: std.mem.Allocator,
    io: std.Io,
    argv: []const []const u8,
) !?ProbeResult {
    const result = std.process.run(allocator, io, .{
        .argv = argv,
        .stdout_limit = .limited(16 * 1024),
        .stderr_limit = .limited(16 * 1024),
    }) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    return switch (result.term) {
        .exited => |code| if (code == 0 and firstNonEmptyLine(result.stdout) != null)
            ProbeResult{
                .available = true,
                .detail = try makeProbeDetail(allocator, result.stdout, "found"),
            }
        else
            ProbeResult{
                .available = false,
                .detail = try makeProbeDetail(allocator, result.stderr, "not found in PATH"),
            },
        else => ProbeResult{
            .available = false,
            .detail = try allocator.dupe(u8, "locator terminated unexpectedly"),
        },
    };
}

fn runVersionProbe(allocator: std.mem.Allocator, io: std.Io, manager_name: []const u8) !ProbeResult {
    const result = std.process.run(allocator, io, .{
        .argv = &.{ manager_name, "--version" },
        .stdout_limit = .limited(16 * 1024),
        .stderr_limit = .limited(16 * 1024),
    }) catch |err| switch (err) {
        error.FileNotFound => {
            return .{
                .available = false,
                .detail = try allocator.dupe(u8, "not found in PATH"),
            };
        },
        else => return err,
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    return switch (result.term) {
        .exited => |code| if (code == 0)
            .{
                .available = true,
                .detail = try makeProbeDetail(allocator, result.stdout, "version probe succeeded"),
            }
        else
            .{
                .available = true,
                .detail = try makeProbeDetail(allocator, result.stderr, "version probe exited non-zero"),
            },
        else => .{
            .available = true,
            .detail = try allocator.dupe(u8, "version probe terminated unexpectedly"),
        },
    };
}

fn probeManager(allocator: std.mem.Allocator, io: std.Io, manager_name: []const u8) !ProbeResult {
    if (builtin.os.tag == .windows) {
        if (try runLocator(allocator, io, &.{ "where.exe", manager_name })) |probe| {
            return probe;
        }
    } else {
        if (try runLocator(allocator, io, &.{ "which", manager_name })) |probe| {
            return probe;
        }
    }

    return runVersionProbe(allocator, io, manager_name);
}

fn printCapturedOutput(io: std.Io, label: []const u8, bytes: []const u8) void {
    const trimmed = trimWhitespace(bytes);
    if (trimmed.len == 0) return;

    printFmt(io, std.Io.File.stderr(), "{s}:\n", .{label});
    writeAll(io, std.Io.File.stderr(), trimmed);
    writeAll(io, std.Io.File.stderr(), "\n");
}

fn pathExistsWithinScenario(
    allocator: std.mem.Allocator,
    io: std.Io,
    scenario_rel_path: []const u8,
    sub_path: []const u8,
) bool {
    const full_path = std.fs.path.join(allocator, &.{ scenario_rel_path, sub_path }) catch return false;
    defer allocator.free(full_path);

    std.Io.Dir.cwd().access(io, full_path, .{}) catch return false;
    return true;
}

fn runScenario(
    allocator: std.mem.Allocator,
    io: std.Io,
    mg_path: []const u8,
    scenario: *const ScenarioSpec,
) !ScenarioStatus {
    const probe = try probeManager(allocator, io, scenario.manager_name);
    defer allocator.free(probe.detail);

    if (!probe.available) {
        printFmt(
            io,
            std.Io.File.stdout(),
            "[SKIP] {s}: `{s}` unavailable ({s})\n",
            .{ scenario.name, scenario.manager_name, probe.detail },
        );
        return .skip;
    }

    const scenario_rel_path = try std.fmt.allocPrint(allocator, ".zig-cache/smoke/{s}", .{scenario.name});
    defer allocator.free(scenario_rel_path);

    try prepareScenarioDir(io, scenario_rel_path, scenario.files);

    const scenario_start_path = if (scenario.start_dir) |start_dir|
        try std.fs.path.join(allocator, &.{ scenario_rel_path, start_dir })
    else
        try allocator.dupe(u8, scenario_rel_path);
    defer allocator.free(scenario_start_path);

    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(allocator);

    try appendAllStrings(&argv, allocator, &.{ mg_path, "-C", scenario_start_path });
    try appendAllStrings(&argv, allocator, scenario.mg_args);

    const preview = try formatCommandPreview(allocator, argv.items);
    defer allocator.free(preview);

    printFmt(io, std.Io.File.stdout(), "[RUN ] {s}: {s}\n", .{ scenario.name, preview });

    const result = try std.process.run(allocator, io, .{
        .argv = argv.items,
        .stdout_limit = .limited(2 * 1024 * 1024),
        .stderr_limit = .limited(2 * 1024 * 1024),
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const expected_manager = try std.fmt.allocPrint(
        allocator,
        "Using {s} package manager",
        .{scenario.manager_name},
    );
    defer allocator.free(expected_manager);

    const term_ok = switch (result.term) {
        .exited => |code| code == 0,
        else => false,
    };
    const manager_banner_ok = containsAny(result.stdout, result.stderr, expected_manager);
    const marker_ok = if (scenario.expected_marker) |marker|
        containsAny(result.stdout, result.stderr, marker)
    else
        true;
    const preview_ok = if (scenario.expected_preview) |preview_marker|
        containsAny(result.stdout, result.stderr, preview_marker)
    else
        true;
    const generated_path_ok = if (scenario.expected_generated_path) |generated_path|
        pathExistsWithinScenario(allocator, io, scenario_rel_path, generated_path)
    else
        true;

    if (!term_ok) {
        if (knownEnvironmentSkipReason(scenario, result.stdout, result.stderr)) |reason| {
            printFmt(
                io,
                std.Io.File.stdout(),
                "[SKIP] {s}: `{s}` blocked by local environment ({s})\n",
                .{ scenario.name, scenario.manager_name, reason },
            );
            return .skip;
        }
    }

    if (term_ok and manager_banner_ok and marker_ok and preview_ok and generated_path_ok) {
        printFmt(
            io,
            std.Io.File.stdout(),
            "[PASS] {s}: manager={s}, probe={s}\n",
            .{ scenario.name, scenario.manager_name, probe.detail },
        );
        return .pass;
    }

    printFmt(
        io,
        std.Io.File.stderr(),
        "[FAIL] {s}: manager={s}, probe={s}\n",
        .{ scenario.name, scenario.manager_name, probe.detail },
    );

    if (!term_ok) {
        printFmt(io, std.Io.File.stderr(), "Reason: command exited unsuccessfully\n", .{});
    } else if (!manager_banner_ok) {
        printFmt(io, std.Io.File.stderr(), "Reason: missing manager detection banner `{s}`\n", .{expected_manager});
    } else if (!generated_path_ok) {
        printFmt(io, std.Io.File.stderr(), "Reason: missing generated path `{s}`\n", .{scenario.expected_generated_path.?});
    } else if (!preview_ok) {
        printFmt(io, std.Io.File.stderr(), "Reason: missing preview marker `{s}`\n", .{scenario.expected_preview.?});
    } else if (!marker_ok) {
        printFmt(io, std.Io.File.stderr(), "Reason: missing scenario marker `{s}`\n", .{scenario.expected_marker.?});
    }

    printCapturedOutput(io, "stdout", result.stdout);
    printCapturedOutput(io, "stderr", result.stderr);
    return .fail;
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try collectArgs(allocator, init.minimal.args);
    defer freeArgs(allocator, args);

    if (args.len < 2) {
        printUsage(init.io);
        return error.InvalidUsage;
    }

    const mg_path = args[1];
    const filters = args[2..];
    try validateFilters(init.io, filters);

    var selected_count: usize = 0;
    var pass_count: usize = 0;
    var skip_count: usize = 0;
    var fail_count: usize = 0;

    for (scenarios) |scenario| {
        if (!scenarioSelected(scenario.name, filters)) continue;

        selected_count += 1;
        switch (try runScenario(allocator, init.io, mg_path, &scenario)) {
            .pass => pass_count += 1,
            .skip => skip_count += 1,
            .fail => fail_count += 1,
        }
    }

    if (selected_count == 0) {
        printUsage(init.io);
        return error.InvalidUsage;
    }

    printFmt(
        init.io,
        std.Io.File.stdout(),
        "\nSmoke summary: selected={d}, passed={d}, skipped={d}, failed={d}\n",
        .{ selected_count, pass_count, skip_count, fail_count },
    );

    if (fail_count != 0) {
        return error.SmokeFailed;
    }
}
