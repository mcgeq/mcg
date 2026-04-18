/// Core type definitions for the mg multi-package manager CLI.
///
/// This module defines the fundamental types used throughout the application,
/// including package manager enumerations, configuration structures, and
/// command execution interfaces.
const std = @import("std");
const MgError = @import("error.zig").MgError;

pub const FixedOptionValues = struct {
    pub const max_items = 7;

    len: usize = 0,
    values: [max_items][]const u8 = undefined,

    pub fn add(self: *@This(), value: []const u8) bool {
        if (self.len >= self.values.len) return false;
        self.values[self.len] = value;
        self.len += 1;
        return true;
    }

    pub fn items(self: *const @This()) []const []const u8 {
        return self.values[0..self.len];
    }

    pub fn last(self: *const @This()) ?[]const u8 {
        if (self.len == 0) return null;
        return self.values[self.len - 1];
    }
};

/// Enumeration of all supported package managers.
///
/// Each package manager has a specific ecosystem and tooling:
///   - Rust: Cargo (Rust dependency management)
///   - JavaScript: npm, pnpm, yarn, bun (Node.js package management)
///   - Python: pip, uv, poetry, pdm (Python package management)
///
/// Detection Priority (lower number = higher priority):
///   0: Cargo (highest priority - checked first)
///   1-4: JavaScript ecosystem managers
///   5-8: Python ecosystem managers
pub const ManagerType = enum(u8) {
    /// Rust package manager (Cargo.toml)
    cargo,
    /// Node.js package manager (npm)
    npm,
    /// Node.js package manager (pnpm)
    pnpm,
    /// Node.js package manager (Bun)
    bun,
    /// Node.js package manager (Yarn)
    yarn,
    /// Python package manager (pip)
    pip,
    /// Python project/package manager (uv)
    uv,
    /// Python dependency management tool (Poetry)
    poetry,
    /// Python package manager (PDM)
    pdm,
};

/// Options for package operations.
///
/// This structure holds configuration options for how packages should be
/// added, removed, or otherwise manipulated by the package manager.
///
/// Fields:
///   - dev: Whether to install packages as dev dependencies
///   - group: Optional primary explicit profile/group name kept for backward compatibility
///   - additional_groups: Extra explicit profiles/groups collected from repeated flags
///   - dry_run: Whether to preview the command without executing it
///
/// Example:
///   ```zig
///   var opts: PackageOptions = .{};
///   opts.dev = true;
///   _ = opts.addProfile("docs");
///   ```
pub const PackageOptions = struct {
    pub const max_groups = FixedOptionValues.max_items + 1;

    /// Install package as a development dependency.
    dev: bool = false,
    /// Optional primary dependency group/profile to target.
    group: ?[]const u8 = null,
    /// Additional dependency groups/profiles collected from repeated flags.
    additional_groups: FixedOptionValues = .{},
    /// Optional working directory used for detection and child process execution.
    cwd: ?[]const u8 = null,
    /// Preview command without executing (dry-run mode).
    dry_run: bool = false,

    pub fn addGroup(self: *@This(), value: []const u8) bool {
        if (self.group == null) {
            self.group = value;
            return true;
        }
        return self.additional_groups.add(value);
    }

    pub fn addProfile(self: *@This(), value: []const u8) bool {
        return self.addGroup(value);
    }

    pub fn groupCount(self: *const @This()) usize {
        return @intFromBool(self.group != null) + self.additional_groups.len;
    }

    pub fn profileCount(self: *const @This()) usize {
        return self.groupCount();
    }

    pub fn groupAt(self: *const @This(), index: usize) ?[]const u8 {
        if (self.group == null) return null;
        if (index == 0) return self.group;

        const extra_index = index - 1;
        if (extra_index >= self.additional_groups.len) return null;
        return self.additional_groups.items()[extra_index];
    }

    pub fn profileAt(self: *const @This(), index: usize) ?[]const u8 {
        return self.groupAt(index);
    }

    pub fn lastGroup(self: *const @This()) ?[]const u8 {
        if (self.additional_groups.last()) |group| return group;
        return self.group;
    }

    pub fn lastExplicitProfile(self: *const @This()) ?[]const u8 {
        return self.lastGroup();
    }

    pub fn hasExplicitGroup(self: *const @This(), name: []const u8) bool {
        var index: usize = 0;
        while (self.groupAt(index)) |group| : (index += 1) {
            if (std.mem.eql(u8, group, name)) return true;
        }
        return false;
    }

    pub fn hasExplicitProfile(self: *const @This(), name: []const u8) bool {
        return self.hasExplicitGroup(name);
    }

    pub fn targetProfile(self: *const @This()) ?[]const u8 {
        if (self.lastExplicitProfile()) |profile| return profile;
        if (self.dev) return "dev";
        return null;
    }

    pub fn effectiveProfileCount(self: *const @This()) usize {
        return self.profileCount() + @intFromBool(self.dev and !self.hasExplicitProfile("dev"));
    }

    pub fn effectiveProfileAt(self: *const @This(), index: usize) ?[]const u8 {
        const include_dev = self.dev and !self.hasExplicitProfile("dev");
        if (include_dev) {
            if (index == 0) return "dev";
            return self.profileAt(index - 1);
        }
        return self.profileAt(index);
    }
};

/// Arguments for package manager command execution.
///
/// This structure separates the target packages from the package manager's
/// native command arguments, allowing for unified command construction.
///
/// Fields:
///   - packages: List of package names to operate on
///   - manager_args: Package-manager-specific arguments (flags, options, etc.)
///
/// Example:
///   ```zig
///   var cmd_args = CommandArgs.init(allocator);
///   defer cmd_args.deinit();
///   try cmd_args.addPackage("serde");
///   try cmd_args.addManagerArg("--features=derive");
/// ```
pub const CommandArgs = struct {
    allocator: std.mem.Allocator,
    /// List of package names to install, remove, or upgrade.
    packages: std.ArrayList([]const u8) = .empty,
    /// Additional arguments specific to the package manager.
    manager_args: std.ArrayList([]const u8) = .empty,

    /// Initializes a new CommandArgs instance.
    ///
    /// Parameters:
    ///   - allocator: Memory allocator for the internal lists
    ///
    /// Returns:
    ///   A new CommandArgs with initialized empty lists
    pub fn init(allocator: std.mem.Allocator) CommandArgs {
        return CommandArgs{
            .allocator = allocator,
        };
    }

    /// Releases all resources held by this CommandArgs.
    ///
    /// Frees both the packages and manager_args lists.
    pub fn deinit(self: *CommandArgs) void {
        self.packages.deinit(self.allocator);
        self.manager_args.deinit(self.allocator);
    }

    pub fn addPackage(self: *CommandArgs, arg: []const u8) !void {
        try self.packages.append(self.allocator, arg);
    }

    pub fn addManagerArg(self: *CommandArgs, arg: []const u8) !void {
        try self.manager_args.append(self.allocator, arg);
    }
};

/// Interface definition for a package manager implementation.
///
/// This structure defines the function pointers that each package manager
/// must implement to integrate with the mg CLI. The interface allows for
/// a unified command interface across different package managers.
///
/// Fields:
///   - name: Function that returns the package manager's display name
///   - formatCommand: Function that formats the command string for execution
///   - execute: Function that executes the command
///
/// Note: This is primarily used for extensibility. Currently, mg uses
/// command-string construction rather than function-pointer invocation.
pub const PackageManager = struct {
    /// Returns the display name of this package manager.
    name: *const fn () []const u8,
    /// Formats the command string for the given action and packages.
    formatCommand: *const fn (command: []const u8, packages: [][]const u8, options: *PackageOptions) []const u8,
    /// Executes the command for the given action and packages.
    execute: *const fn (command: []const u8, packages: [][]const u8, options: *PackageOptions) MgError!void,
};

/// Converts a ManagerType enum value to its string representation.
///
/// Parameters:
///   - manager_type: The ManagerType to convert
///
/// Returns:
///   A string slice containing the package manager's command name
///
/// Example:
///   ```zig
///   const name = getManagerName(.cargo);  // returns "cargo"
///   const name = getManagerName(.poetry); // returns "poetry"
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

/// Parses a string to a ManagerType enum value.
///
/// Performs case-insensitive matching against known package manager names.
///
/// Parameters:
///   - name: The string to parse (case-insensitive)
///
/// Returns:
///   ManagerType if the string matches a known package manager, null otherwise
///
/// Example:
///   ```zig
///   const mt = parseManagerType("Cargo");  // returns .cargo
///   const mt = parseManagerType("NPM");    // returns .npm
///   const mt = parseManagerType("unknown"); // returns null
/// ```
pub fn parseManagerType(name: []const u8) ?ManagerType {
    var lower_buf: [32]u8 = undefined;
    const lower = std.ascii.lowerString(&lower_buf, name);
    if (std.mem.eql(u8, lower, "cargo")) return .cargo;
    if (std.mem.eql(u8, lower, "npm")) return .npm;
    if (std.mem.eql(u8, lower, "pnpm")) return .pnpm;
    if (std.mem.eql(u8, lower, "bun")) return .bun;
    if (std.mem.eql(u8, lower, "yarn")) return .yarn;
    if (std.mem.eql(u8, lower, "pip")) return .pip;
    if (std.mem.eql(u8, lower, "uv")) return .uv;
    if (std.mem.eql(u8, lower, "poetry")) return .poetry;
    if (std.mem.eql(u8, lower, "pdm")) return .pdm;
    return null;
}

test "package options effective profiles include dev and explicit groups" {
    var options: PackageOptions = .{
        .dev = true,
    };
    try std.testing.expect(options.addGroup("docs"));
    try std.testing.expect(options.addGroup("lint"));

    try std.testing.expectEqual(@as(usize, 3), options.effectiveProfileCount());
    try std.testing.expectEqualStrings("dev", options.effectiveProfileAt(0).?);
    try std.testing.expectEqualStrings("docs", options.effectiveProfileAt(1).?);
    try std.testing.expectEqualStrings("lint", options.effectiveProfileAt(2).?);
    try std.testing.expect(options.effectiveProfileAt(3) == null);
}

test "package options dedupe implicit dev profile when dev group is explicit" {
    var options: PackageOptions = .{
        .dev = true,
    };
    try std.testing.expect(options.addGroup("dev"));
    try std.testing.expect(options.addGroup("docs"));

    try std.testing.expectEqual(@as(usize, 2), options.effectiveProfileCount());
    try std.testing.expectEqualStrings("dev", options.effectiveProfileAt(0).?);
    try std.testing.expectEqualStrings("docs", options.effectiveProfileAt(1).?);
    try std.testing.expect(options.effectiveProfileAt(2) == null);
}

test "package options target profile prefers last explicit group over dev" {
    var options: PackageOptions = .{
        .dev = true,
    };
    try std.testing.expect(options.addGroup("docs"));
    try std.testing.expect(options.addGroup("lint"));

    try std.testing.expectEqualStrings("lint", options.targetProfile().?);
}

test "package options profile aliases match group storage" {
    var options: PackageOptions = .{};
    try std.testing.expect(options.addProfile("docs"));
    try std.testing.expect(options.addProfile("lint"));

    try std.testing.expectEqual(@as(usize, 2), options.profileCount());
    try std.testing.expectEqualStrings("docs", options.profileAt(0).?);
    try std.testing.expectEqualStrings("lint", options.profileAt(1).?);
    try std.testing.expectEqualStrings("lint", options.lastExplicitProfile().?);
    try std.testing.expect(options.hasExplicitProfile("docs"));
}
