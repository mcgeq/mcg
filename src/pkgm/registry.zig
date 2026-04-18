/// Package manager command registry.
///
/// This module maps short-hand commands to package-manager-specific commands.
/// It provides a unified interface for common operations across all supported
/// package managers, translating simple commands like "add" or "remove" into
/// the appropriate native commands for each ecosystem.
const std = @import("std");
const CommandArgs = @import("../core/types.zig").CommandArgs;
const ManagerType = @import("../core/types.zig").ManagerType;
const PackageOptions = @import("../core/types.zig").PackageOptions;

/// Returns the command-line name for a given package manager.
///
/// Parameters:
///   - manager_type: The ManagerType enum value
///
/// Returns:
///   A string slice containing the executable name for the package manager
///
/// Example:
///   ```zig
///   const name = getManagerName(.cargo);  // returns "cargo"
///   const name = getManagerName(.pnpm);   // returns "pnpm"
/// ```
pub fn getManagerName(manager_type: ManagerType) []const u8 {
    return switch (manager_type) {
        .cargo => "cargo",
        .npm => "npm",
        .pnpm => "pnpm",
        .bun => "bun",
        .yarn => "yarn",
        .pip => "pip",
        .uv => "uv",
        .poetry => "poetry",
        .pdm => "pdm",
    };
}

pub fn appendCommandArgs(
    argv: *std.ArrayList([]const u8),
    allocator: std.mem.Allocator,
    manager_type: ManagerType,
    action: []const u8,
    command_args: *const CommandArgs,
    options: *const PackageOptions,
) !bool {
    const packages = command_args.packages.items;
    const manager_args = command_args.manager_args.items;

    if (isExecAction(action)) {
        if (manager_args.len == 0) return false;
        try appendAll(argv, allocator, manager_args);
        return true;
    }

    if (isRunAction(action)) {
        switch (manager_type) {
            .cargo, .npm, .pnpm, .bun, .yarn, .uv, .poetry, .pdm => try argv.append(allocator, "run"),
            .pip => return false,
        }
        if (packages.len == 0) return false;
        try appendAll(argv, allocator, packages);
        if (manager_args.len > 0 and (manager_type == .npm or manager_type == .pnpm)) {
            try argv.append(allocator, "--");
        }
        try appendAll(argv, allocator, manager_args);
        return true;
    }

    if (isAddAction(action)) {
        switch (manager_type) {
            .cargo => try argv.append(allocator, "add"),
            .npm => try argv.append(allocator, "install"),
            .pnpm, .bun, .yarn => try argv.append(allocator, "add"),
            .pip => try argv.append(allocator, "install"),
            .uv => try argv.append(allocator, "add"),
            .poetry, .pdm => try argv.append(allocator, "add"),
        }
        try appendOptionArgs(argv, allocator, manager_type, .add, options);
        if (packages.len == 0 and manager_args.len == 0) return false;
        for (packages) |pkg| {
            try argv.append(allocator, pkg);
        }
        try appendAll(argv, allocator, manager_args);
        return true;
    }

    if (isRemoveAction(action)) {
        switch (manager_type) {
            .cargo => try argv.append(allocator, "remove"),
            .npm => try argv.append(allocator, "uninstall"),
            .pnpm, .bun, .yarn => try argv.append(allocator, "remove"),
            .pip => try argv.append(allocator, "uninstall"),
            .uv => try argv.append(allocator, "remove"),
            .poetry, .pdm => try argv.append(allocator, "remove"),
        }
        try appendOptionArgs(argv, allocator, manager_type, .remove, options);
        if (packages.len == 0 and manager_args.len == 0) return false;
        for (packages) |pkg| {
            try argv.append(allocator, pkg);
        }
        try appendAll(argv, allocator, manager_args);
        return true;
    }

    if (isUpgradeAction(action)) {
        switch (manager_type) {
            .cargo => try argv.append(allocator, "update"),
            .npm, .pnpm, .bun => try argv.append(allocator, "update"),
            .yarn => try argv.append(allocator, "up"),
            .pip => {
                try argv.append(allocator, "install");
                try argv.append(allocator, "--upgrade");
            },
            .uv => {
                try argv.append(allocator, "sync");
                try appendOptionArgs(argv, allocator, manager_type, .upgrade, options);
                if (packages.len == 0) {
                    try argv.append(allocator, "--upgrade");
                } else {
                    for (packages) |pkg| {
                        try argv.append(allocator, "--upgrade-package");
                        try argv.append(allocator, pkg);
                    }
                }
                try appendAll(argv, allocator, manager_args);
                return true;
            },
            .poetry => {
                try argv.append(allocator, "update");
            },
            .pdm => {
                try argv.append(allocator, "update");
            },
        }
        try appendOptionArgs(argv, allocator, manager_type, .upgrade, options);
        if (packages.len == 0 and manager_args.len == 0 and manager_type == .pip) return false;
        try appendAll(argv, allocator, packages);
        try appendAll(argv, allocator, manager_args);
        return true;
    }

    if (isInstallAction(action)) {
        switch (manager_type) {
            .cargo => try argv.append(allocator, "check"),
            .npm, .pnpm, .bun, .yarn, .pip => try argv.append(allocator, "install"),
            .uv => try argv.append(allocator, "sync"),
            .poetry => try argv.append(allocator, "install"),
            .pdm => try argv.append(allocator, "install"),
        }
        try appendOptionArgs(argv, allocator, manager_type, .install, options);
        try appendAll(argv, allocator, packages);
        try appendAll(argv, allocator, manager_args);
        return true;
    }

    if (isListAction(action)) {
        switch (manager_type) {
            .cargo => try argv.append(allocator, "tree"),
            .npm, .pnpm, .bun, .yarn, .pip, .pdm => try argv.append(allocator, "list"),
            .uv => try argv.append(allocator, "tree"),
            .poetry => try argv.append(allocator, "show"),
        }
        try appendOptionArgs(argv, allocator, manager_type, .list, options);
        try appendAll(argv, allocator, packages);
        try appendAll(argv, allocator, manager_args);
        return true;
    }

    return false;
}

pub fn actionRequiresPackages(action: []const u8) bool {
    return isAddAction(action) or isRemoveAction(action);
}

pub fn actionRequiresRunTarget(action: []const u8) bool {
    return isRunAction(action);
}

const ActionKind = enum {
    add,
    remove,
    upgrade,
    install,
    list,
};

fn appendOptionArgs(
    argv: *std.ArrayList([]const u8),
    allocator: std.mem.Allocator,
    manager_type: ManagerType,
    action_kind: ActionKind,
    options: *const PackageOptions,
) !void {
    switch (action_kind) {
        .add => switch (manager_type) {
            .cargo => if (options.dev) try argv.append(allocator, "--dev"),
            .npm, .pnpm => if (options.dev) try argv.append(allocator, "--save-dev"),
            .bun, .yarn => if (options.dev) try argv.append(allocator, "--dev"),
            .uv => {
                try appendUvTargetProfileSelection(argv, allocator, options);
            },
            .poetry => if (targetProfile(options)) |group| {
                try argv.append(allocator, "--group");
                try argv.append(allocator, group);
            },
            .pdm => try appendPdmTargetProfileSelection(argv, allocator, options),
            .pip => {},
        },
        .remove => switch (manager_type) {
            .cargo => if (options.dev) try argv.append(allocator, "--dev"),
            .npm, .pnpm => if (options.dev) try argv.append(allocator, "--save-dev"),
            .uv => {
                try appendUvTargetProfileSelection(argv, allocator, options);
            },
            .poetry => if (targetProfile(options)) |group| {
                try argv.append(allocator, "--group");
                try argv.append(allocator, group);
            },
            .pdm => try appendPdmTargetProfileSelection(argv, allocator, options),
            .bun, .yarn, .pip => {},
        },
        .upgrade => switch (manager_type) {
            .uv => try appendAllEffectiveProfiles(argv, allocator, "--group", options),
            .pdm => try appendPdmEffectiveProfileSelection(argv, allocator, options),
            .cargo, .npm, .pnpm, .bun, .yarn, .pip, .poetry => {},
        },
        .install => switch (manager_type) {
            .uv => try appendAllEffectiveProfiles(argv, allocator, "--group", options),
            .poetry => try appendAllEffectiveProfiles(argv, allocator, "--with", options),
            .pdm => try appendPdmEffectiveProfileSelection(argv, allocator, options),
            .cargo, .npm, .pnpm, .bun, .yarn, .pip => {},
        },
        .list => switch (manager_type) {
            .uv => try appendAllEffectiveProfiles(argv, allocator, "--group", options),
            .pdm => try appendPdmEffectiveProfileSelection(argv, allocator, options),
            .cargo, .npm, .pnpm, .bun, .yarn, .pip, .poetry => {},
        },
    }
}

fn appendAll(argv: *std.ArrayList([]const u8), allocator: std.mem.Allocator, values: []const []const u8) !void {
    for (values) |value| {
        try argv.append(allocator, value);
    }
}

fn targetProfile(options: *const PackageOptions) ?[]const u8 {
    return options.targetProfile();
}

fn appendTargetProfile(
    argv: *std.ArrayList([]const u8),
    allocator: std.mem.Allocator,
    flag: []const u8,
    options: *const PackageOptions,
) !void {
    if (options.targetProfile()) |profile| {
        try argv.append(allocator, flag);
        try argv.append(allocator, profile);
    }
}

fn appendUvTargetProfileSelection(
    argv: *std.ArrayList([]const u8),
    allocator: std.mem.Allocator,
    options: *const PackageOptions,
) !void {
    if (targetProfile(options)) |profile| {
        if (isDevProfile(profile) and !options.hasExplicitProfile("dev")) {
            if (options.dev) try argv.append(allocator, "--dev");
            return;
        }

        if (options.dev and !isDevProfile(profile)) {
            try argv.append(allocator, "--dev");
        }
        try argv.append(allocator, "--group");
        try argv.append(allocator, profile);
        return;
    }

    if (options.dev) try argv.append(allocator, "--dev");
}

fn appendAllExplicitGroups(
    argv: *std.ArrayList([]const u8),
    allocator: std.mem.Allocator,
    flag: []const u8,
    options: *const PackageOptions,
) !void {
    var index: usize = 0;
    while (options.groupAt(index)) |group| : (index += 1) {
        try argv.append(allocator, flag);
        try argv.append(allocator, group);
    }
}

fn appendAllEffectiveProfiles(
    argv: *std.ArrayList([]const u8),
    allocator: std.mem.Allocator,
    flag: []const u8,
    options: *const PackageOptions,
) !void {
    var index: usize = 0;
    while (options.effectiveProfileAt(index)) |profile| : (index += 1) {
        try argv.append(allocator, flag);
        try argv.append(allocator, profile);
    }
}

fn appendPdmTargetProfileSelection(
    argv: *std.ArrayList([]const u8),
    allocator: std.mem.Allocator,
    options: *const PackageOptions,
) !void {
    if (targetProfile(options)) |profile| {
        if (isDevProfile(profile)) {
            try argv.append(allocator, "--dev");
            return;
        }

        if (options.dev) try argv.append(allocator, "--dev");
        try argv.append(allocator, "--group");
        try argv.append(allocator, profile);
        return;
    }

    if (options.dev) try argv.append(allocator, "--dev");
}

fn appendPdmEffectiveProfileSelection(
    argv: *std.ArrayList([]const u8),
    allocator: std.mem.Allocator,
    options: *const PackageOptions,
) !void {
    var include_dev = options.dev;
    var index: usize = 0;
    while (options.profileAt(index)) |profile| : (index += 1) {
        if (isDevProfile(profile)) include_dev = true;
    }

    if (include_dev) try argv.append(allocator, "--dev");

    index = 0;
    while (options.profileAt(index)) |profile| : (index += 1) {
        if (isDevProfile(profile)) continue;

        try argv.append(allocator, "--group");
        try argv.append(allocator, profile);
    }
}

fn isDevProfile(profile: []const u8) bool {
    return std.mem.eql(u8, profile, "dev");
}

fn isAddAction(action: []const u8) bool {
    return actionEq(action, "add") or actionEq(action, "a");
}

fn isRemoveAction(action: []const u8) bool {
    return actionEq(action, "remove") or actionEq(action, "rm") or actionEq(action, "r");
}

fn isUpgradeAction(action: []const u8) bool {
    return actionEq(action, "upgrade") or actionEq(action, "update") or actionEq(action, "u");
}

fn isInstallAction(action: []const u8) bool {
    return actionEq(action, "install") or actionEq(action, "i");
}

fn isListAction(action: []const u8) bool {
    return actionEq(action, "list") or actionEq(action, "analyze") or actionEq(action, "l");
}

fn isExecAction(action: []const u8) bool {
    return actionEq(action, "exec") or actionEq(action, "x");
}

fn isRunAction(action: []const u8) bool {
    return actionEq(action, "run");
}

fn actionEq(action: []const u8, expected: []const u8) bool {
    return std.ascii.eqlIgnoreCase(action, expected);
}

fn packageLiteral(comptime value: [:0]const u8) [:0]u8 {
    return @constCast(value);
}

fn optionsWithGroups(groups: []const []const u8, dev: bool) PackageOptions {
    var options: PackageOptions = .{
        .dev = dev,
    };

    for (groups) |group| {
        const appended = options.addGroup(group);
        std.debug.assert(appended);
    }

    return options;
}

fn expectCommand(
    manager_type: ManagerType,
    action: []const u8,
    packages: []const [:0]u8,
    manager_args: []const []const u8,
    options: PackageOptions,
    expected: []const []const u8,
) !void {
    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(std.testing.allocator);
    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();

    for (packages) |pkg| {
        try command_args.addPackage(pkg);
    }
    for (manager_args) |arg| {
        try command_args.addManagerArg(arg);
    }

    try argv.append(std.testing.allocator, getManagerName(manager_type));
    try std.testing.expect(try appendCommandArgs(&argv, std.testing.allocator, manager_type, action, &command_args, &options));
    try std.testing.expectEqual(expected.len, argv.items.len);

    for (expected, argv.items) |want, got| {
        try std.testing.expectEqualStrings(want, got);
    }
}

fn expectNoCommand(manager_type: ManagerType, action: []const u8, packages: []const [:0]u8, manager_args: []const []const u8) !void {
    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(std.testing.allocator);
    var command_args = CommandArgs.init(std.testing.allocator);
    defer command_args.deinit();

    for (packages) |pkg| {
        try command_args.addPackage(pkg);
    }
    for (manager_args) |arg| {
        try command_args.addManagerArg(arg);
    }

    try argv.append(std.testing.allocator, getManagerName(manager_type));
    try std.testing.expect(!try appendCommandArgs(&argv, std.testing.allocator, manager_type, action, &command_args, &.{}));
}

test "uv command mappings" {
    try expectCommand(.uv, "add", &.{packageLiteral("requests")}, &.{}, .{}, &.{ "uv", "add", "requests" });
    try expectCommand(.uv, "remove", &.{packageLiteral("requests")}, &.{}, .{}, &.{ "uv", "remove", "requests" });
    try expectCommand(.uv, "install", &.{}, &.{}, .{}, &.{ "uv", "sync" });
    try expectCommand(.uv, "list", &.{}, &.{}, .{}, &.{ "uv", "tree" });
    try expectCommand(.uv, "upgrade", &.{}, &.{}, .{}, &.{ "uv", "sync", "--upgrade" });
    try expectCommand(.uv, "upgrade", &.{packageLiteral("requests")}, &.{}, .{}, &.{ "uv", "sync", "--upgrade-package", "requests" });
}

test "poetry command mappings" {
    try expectCommand(.poetry, "add", &.{packageLiteral("requests")}, &.{}, .{}, &.{ "poetry", "add", "requests" });
    try expectCommand(.poetry, "remove", &.{packageLiteral("requests")}, &.{}, .{}, &.{ "poetry", "remove", "requests" });
    try expectCommand(.poetry, "install", &.{}, &.{}, .{}, &.{ "poetry", "install" });
    try expectCommand(.poetry, "list", &.{}, &.{}, .{}, &.{ "poetry", "show" });
    try expectCommand(.poetry, "upgrade", &.{packageLiteral("requests")}, &.{}, .{}, &.{ "poetry", "update", "requests" });
}

test "pdm command mappings" {
    try expectCommand(.pdm, "add", &.{packageLiteral("requests")}, &.{}, .{}, &.{ "pdm", "add", "requests" });
    try expectCommand(.pdm, "remove", &.{packageLiteral("requests")}, &.{}, .{}, &.{ "pdm", "remove", "requests" });
    try expectCommand(.pdm, "install", &.{}, &.{}, .{}, &.{ "pdm", "install" });
    try expectCommand(.pdm, "list", &.{}, &.{}, .{}, &.{ "pdm", "list" });
    try expectCommand(.pdm, "upgrade", &.{packageLiteral("requests")}, &.{}, .{}, &.{ "pdm", "update", "requests" });
}

test "pip upgrade requires explicit packages" {
    try expectNoCommand(.pip, "upgrade", &.{}, &.{});
    try expectCommand(.pip, "upgrade", &.{ packageLiteral("requests"), packageLiteral("httpx") }, &.{}, .{}, &.{ "pip", "install", "--upgrade", "requests", "httpx" });
}

test "analyze action maps to list commands" {
    try expectCommand(.npm, "analyze", &.{}, &.{}, .{}, &.{ "npm", "list" });
    try expectCommand(.uv, "analyze", &.{}, &.{}, .{}, &.{ "uv", "tree" });
    try expectCommand(.poetry, "analyze", &.{}, &.{}, .{}, &.{ "poetry", "show" });
}

test "dev and group options map per manager" {
    try expectCommand(.npm, "add", &.{packageLiteral("vitest")}, &.{}, .{ .dev = true }, &.{ "npm", "install", "--save-dev", "vitest" });
    try expectCommand(.pnpm, "add", &.{packageLiteral("vitest")}, &.{}, .{ .dev = true }, &.{ "pnpm", "add", "--save-dev", "vitest" });
    try expectCommand(.bun, "add", &.{packageLiteral("vitest")}, &.{}, .{ .dev = true }, &.{ "bun", "add", "--dev", "vitest" });
    try expectCommand(.yarn, "add", &.{packageLiteral("vitest")}, &.{}, .{ .dev = true }, &.{ "yarn", "add", "--dev", "vitest" });
    try expectCommand(.cargo, "add", &.{packageLiteral("insta")}, &.{}, .{ .dev = true }, &.{ "cargo", "add", "--dev", "insta" });
    try expectCommand(.uv, "add", &.{packageLiteral("pytest")}, &.{}, .{ .dev = true }, &.{ "uv", "add", "--dev", "pytest" });
    try expectCommand(.uv, "add", &.{packageLiteral("mkdocs")}, &.{}, .{ .group = "docs" }, &.{ "uv", "add", "--group", "docs", "mkdocs" });
    try expectCommand(.poetry, "add", &.{packageLiteral("pytest")}, &.{}, .{ .dev = true }, &.{ "poetry", "add", "--group", "dev", "pytest" });
    try expectCommand(.poetry, "install", &.{}, &.{}, .{ .group = "docs" }, &.{ "poetry", "install", "--with", "docs" });
    try expectCommand(.pdm, "remove", &.{packageLiteral("pytest")}, &.{}, .{ .dev = true, .group = "test" }, &.{ "pdm", "remove", "--dev", "--group", "test", "pytest" });
    try expectCommand(.pdm, "add", &.{packageLiteral("pytest")}, &.{}, .{ .group = "dev" }, &.{ "pdm", "add", "--dev", "pytest" });
}

test "repeated group options expand for install-like actions" {
    try expectCommand(
        .uv,
        "install",
        &.{},
        &.{ "--frozen" },
        optionsWithGroups(&.{ "docs", "test" }, false),
        &.{ "uv", "sync", "--group", "docs", "--group", "test", "--frozen" },
    );
    try expectCommand(
        .poetry,
        "install",
        &.{},
        &.{},
        optionsWithGroups(&.{ "docs", "lint" }, false),
        &.{ "poetry", "install", "--with", "docs", "--with", "lint" },
    );
    try expectCommand(
        .pdm,
        "list",
        &.{},
        &.{},
        optionsWithGroups(&.{ "docs", "lint" }, true),
        &.{ "pdm", "list", "--dev", "--group", "docs", "--group", "lint" },
    );
}

test "dev combines with repeated groups for multi-profile install flows" {
    try expectCommand(
        .uv,
        "install",
        &.{},
        &.{},
        optionsWithGroups(&.{ "docs", "lint" }, true),
        &.{ "uv", "sync", "--group", "dev", "--group", "docs", "--group", "lint" },
    );
    try expectCommand(
        .poetry,
        "install",
        &.{},
        &.{},
        optionsWithGroups(&.{ "docs", "lint" }, true),
        &.{ "poetry", "install", "--with", "dev", "--with", "docs", "--with", "lint" },
    );
}

test "explicit dev group avoids duplicate implicit dev profile" {
    try expectCommand(
        .uv,
        "install",
        &.{},
        &.{},
        optionsWithGroups(&.{ "dev", "docs" }, true),
        &.{ "uv", "sync", "--group", "dev", "--group", "docs" },
    );
    try expectCommand(
        .poetry,
        "install",
        &.{},
        &.{},
        optionsWithGroups(&.{ "dev", "docs" }, true),
        &.{ "poetry", "install", "--with", "dev", "--with", "docs" },
    );
    try expectCommand(
        .pdm,
        "list",
        &.{},
        &.{},
        optionsWithGroups(&.{ "dev", "docs" }, true),
        &.{ "pdm", "list", "--dev", "--group", "docs" },
    );
}

test "repeated group options keep last group for add and remove" {
    try expectCommand(
        .uv,
        "add",
        &.{packageLiteral("mkdocs")},
        &.{},
        optionsWithGroups(&.{ "docs", "lint" }, false),
        &.{ "uv", "add", "--group", "lint", "mkdocs" },
    );
    try expectCommand(
        .poetry,
        "remove",
        &.{packageLiteral("pytest")},
        &.{},
        optionsWithGroups(&.{ "test", "qa" }, false),
        &.{ "poetry", "remove", "--group", "qa", "pytest" },
    );
}

test "manager passthrough args are appended" {
    try expectCommand(.cargo, "add", &.{packageLiteral("serde")}, &.{ "--features", "derive" }, .{}, &.{ "cargo", "add", "serde", "--features", "derive" });
    try expectCommand(.uv, "install", &.{}, &.{ "--frozen" }, .{ .group = "docs" }, &.{ "uv", "sync", "--group", "docs", "--frozen" });
    try expectCommand(.pip, "upgrade", &.{}, &.{ "-r", "requirements-dev.txt" }, .{}, &.{ "pip", "install", "--upgrade", "-r", "requirements-dev.txt" });
}

test "core add and remove mappings cover cargo node and python managers" {
    try expectCommand(.cargo, "add", &.{packageLiteral("serde")}, &.{}, .{}, &.{ "cargo", "add", "serde" });
    try expectCommand(.cargo, "remove", &.{packageLiteral("serde")}, &.{}, .{}, &.{ "cargo", "remove", "serde" });
    try expectCommand(.npm, "add", &.{packageLiteral("lodash")}, &.{}, .{}, &.{ "npm", "install", "lodash" });
    try expectCommand(.npm, "remove", &.{packageLiteral("lodash")}, &.{}, .{}, &.{ "npm", "uninstall", "lodash" });
    try expectCommand(.pnpm, "add", &.{packageLiteral("lodash")}, &.{}, .{}, &.{ "pnpm", "add", "lodash" });
    try expectCommand(.pnpm, "remove", &.{packageLiteral("lodash")}, &.{}, .{}, &.{ "pnpm", "remove", "lodash" });
    try expectCommand(.bun, "add", &.{packageLiteral("lodash")}, &.{}, .{}, &.{ "bun", "add", "lodash" });
    try expectCommand(.bun, "remove", &.{packageLiteral("lodash")}, &.{}, .{}, &.{ "bun", "remove", "lodash" });
    try expectCommand(.yarn, "add", &.{packageLiteral("lodash")}, &.{}, .{}, &.{ "yarn", "add", "lodash" });
    try expectCommand(.yarn, "remove", &.{packageLiteral("lodash")}, &.{}, .{}, &.{ "yarn", "remove", "lodash" });
    try expectCommand(.pip, "add", &.{packageLiteral("requests")}, &.{}, .{}, &.{ "pip", "install", "requests" });
    try expectCommand(.uv, "add", &.{packageLiteral("requests")}, &.{}, .{}, &.{ "uv", "add", "requests" });
    try expectCommand(.poetry, "add", &.{packageLiteral("requests")}, &.{}, .{}, &.{ "poetry", "add", "requests" });
    try expectCommand(.pdm, "add", &.{packageLiteral("requests")}, &.{}, .{}, &.{ "pdm", "add", "requests" });
}

test "upgrade action covers standard managers" {
    try expectCommand(.cargo, "upgrade", &.{}, &.{}, .{}, &.{ "cargo", "update" });
    try expectCommand(.npm, "upgrade", &.{}, &.{}, .{}, &.{ "npm", "update" });
    try expectCommand(.pnpm, "upgrade", &.{}, &.{}, .{}, &.{ "pnpm", "update" });
    try expectCommand(.bun, "upgrade", &.{}, &.{}, .{}, &.{ "bun", "update" });
    try expectCommand(.yarn, "upgrade", &.{packageLiteral("react")}, &.{}, .{}, &.{ "yarn", "up", "react" });
    try expectCommand(.uv, "upgrade", &.{packageLiteral("requests")}, &.{}, .{}, &.{ "uv", "sync", "--upgrade-package", "requests" });
    try expectCommand(.poetry, "upgrade", &.{packageLiteral("requests")}, &.{}, .{}, &.{ "poetry", "update", "requests" });
    try expectCommand(.pdm, "upgrade", &.{packageLiteral("requests")}, &.{}, .{}, &.{ "pdm", "update", "requests" });
    try expectCommand(.pip, "upgrade", &.{packageLiteral("requests")}, &.{}, .{}, &.{ "pip", "install", "--upgrade", "requests" });
}

test "exec action forwards native manager argv" {
    try expectCommand(.cargo, "exec", &.{}, &.{ "check" }, .{}, &.{ "cargo", "check" });
    try expectCommand(.cargo, "exec", &.{}, &.{ "metadata", "--no-deps" }, .{}, &.{ "cargo", "metadata", "--no-deps" });
    try expectCommand(.npm, "exec", &.{}, &.{ "list" }, .{}, &.{ "npm", "list" });
    try expectCommand(.npm, "exec", &.{}, &.{ "exec", "--", "node", "smoke.js" }, .{}, &.{ "npm", "exec", "--", "node", "smoke.js" });
    try expectCommand(.npm, "exec", &.{}, &.{ "run", "smoke" }, .{}, &.{ "npm", "run", "smoke" });
    try expectCommand(.pnpm, "exec", &.{}, &.{ "list" }, .{}, &.{ "pnpm", "list" });
    try expectCommand(.pnpm, "exec", &.{}, &.{ "run", "build:apk" }, .{}, &.{ "pnpm", "run", "build:apk" });
    try expectCommand(.pnpm, "exec", &.{}, &.{ "exec", "node", "smoke.js" }, .{}, &.{ "pnpm", "exec", "node", "smoke.js" });
    try expectCommand(.bun, "exec", &.{}, &.{ "test" }, .{}, &.{ "bun", "test" });
    try expectCommand(.bun, "exec", &.{}, &.{ "run", "smoke" }, .{}, &.{ "bun", "run", "smoke" });
    try expectCommand(.yarn, "exec", &.{}, &.{ "list" }, .{}, &.{ "yarn", "list" });
    try expectCommand(.yarn, "exec", &.{}, &.{ "run", "smoke" }, .{}, &.{ "yarn", "run", "smoke" });
    try expectCommand(.uv, "exec", &.{}, &.{ "sync" }, .{}, &.{ "uv", "sync" });
    try expectCommand(.uv, "exec", &.{}, &.{ "tree" }, .{}, &.{ "uv", "tree" });
    try expectCommand(.cargo, "exec", &.{}, &.{ "test" }, .{}, &.{ "cargo", "test" });
    try expectCommand(.cargo, "exec", &.{}, &.{ "test", "--", "--nocapture" }, .{}, &.{ "cargo", "test", "--", "--nocapture" });
    try expectCommand(.uv, "exec", &.{}, &.{ "lock" }, .{}, &.{ "uv", "lock" });
    try expectCommand(.poetry, "exec", &.{}, &.{ "check" }, .{}, &.{ "poetry", "check" });
    try expectCommand(.poetry, "exec", &.{}, &.{ "show" }, .{}, &.{ "poetry", "show" });
    try expectCommand(.poetry, "exec", &.{}, &.{ "run", "python", "smoke.py" }, .{}, &.{ "poetry", "run", "python", "smoke.py" });
    try expectCommand(.pdm, "exec", &.{}, &.{ "list" }, .{}, &.{ "pdm", "list" });
    try expectCommand(.pdm, "exec", &.{}, &.{ "run", "--list" }, .{}, &.{ "pdm", "run", "--list" });
    try expectCommand(.pdm, "exec", &.{}, &.{ "smoke" }, .{}, &.{ "pdm", "smoke" });
    try expectCommand(.pdm, "exec", &.{}, &.{ "run", "python", "smoke.py" }, .{}, &.{ "pdm", "run", "python", "smoke.py" });
    try expectCommand(.uv, "exec", &.{}, &.{ "run", "python", "app.py" }, .{ .dev = true, .group = "docs" }, &.{ "uv", "run", "python", "app.py" });
}

test "exec action requires native argv" {
    try expectNoCommand(.pnpm, "exec", &.{}, &.{});
}

test "run action maps to native run command" {
    try expectCommand(.pnpm, "run", &.{packageLiteral("build")}, &.{}, .{}, &.{ "pnpm", "run", "build" });
    try expectCommand(.bun, "run", &.{packageLiteral("build:apk")}, &.{}, .{}, &.{ "bun", "run", "build:apk" });
    try expectCommand(.cargo, "run", &.{packageLiteral("server")}, &.{}, .{}, &.{ "cargo", "run", "server" });
    try expectCommand(.uv, "run", &.{packageLiteral("python"), packageLiteral("app.py")}, &.{}, .{}, &.{ "uv", "run", "python", "app.py" });
    try expectCommand(.poetry, "run", &.{packageLiteral("pytest")}, &.{ "-q" }, .{}, &.{ "poetry", "run", "pytest", "-q" });
    try expectCommand(.pdm, "run", &.{packageLiteral("python"), packageLiteral("smoke.py")}, &.{}, .{}, &.{ "pdm", "run", "python", "smoke.py" });
}

test "run action inserts native separator for npm style script args" {
    try expectCommand(.npm, "run", &.{packageLiteral("build")}, &.{ "--watch" }, .{}, &.{ "npm", "run", "build", "--", "--watch" });
    try expectCommand(.pnpm, "run", &.{packageLiteral("build:apk")}, &.{ "--mode", "release" }, .{}, &.{ "pnpm", "run", "build:apk", "--", "--mode", "release" });
}

test "run action rejects unsupported or empty invocation" {
    try expectNoCommand(.pip, "run", &.{packageLiteral("python")}, &.{});
    try expectNoCommand(.pnpm, "run", &.{}, &.{});
    try expectNoCommand(.npm, "run", &.{}, &.{ "--watch" });
}

test "manager args can satisfy add without positional package" {
    try expectCommand(.cargo, "add", &.{}, &.{ "--path", "../local-crate" }, .{}, &.{ "cargo", "add", "--path", "../local-crate" });
}

test "yarn upgrade maps to up" {
    try expectCommand(.yarn, "upgrade", &.{packageLiteral("react")}, &.{}, .{}, &.{ "yarn", "up", "react" });
}
