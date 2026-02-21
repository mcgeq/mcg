/// Core type definitions for the mg multi-package manager CLI.
///
/// This module defines the fundamental types used throughout the application,
/// including package manager enumerations, configuration structures, and
/// command execution interfaces.
const std = @import("std");
const MgError = @import("error.zig").MgError;

/// Enumeration of all supported package managers.
///
/// Each package manager has a specific ecosystem and tooling:
///   - Rust: Cargo (Rust dependency management)
///   - JavaScript: npm, pnpm, yarn, bun (Node.js package management)
///   - Python: pip, poetry, pdm (Python package management)
///
/// Detection Priority (lower number = higher priority):
///   0: Cargo (highest priority - checked first)
///   1-4: JavaScript ecosystem managers
///   5-7: Python ecosystem managers
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
///   - args: Additional command-line arguments to pass to the package manager
///   - dev: Whether to install packages as dev dependencies
///   - dry_run: Whether to preview the command without executing it
///
/// Example:
///   ```zig
///   var opts = PackageOptions.init(allocator);
///   defer opts.deinit();
///   opts.dev = true;
///   opts.addArg("--features=derive");
///   ```
pub const PackageOptions = struct {
    /// Additional command-line arguments to pass to the package manager.
    args: std.ArrayList([]const u8),
    /// Install package as a development dependency.
    dev: bool = false,
    /// Preview command without executing (dry-run mode).
    dry_run: bool = false,

    /// Initializes a new PackageOptions instance.
    ///
    /// Parameters:
    ///   - allocator: Memory allocator for the internal args list
    ///
    /// Returns:
    ///   A new PackageOptions with initialized empty args list
    pub fn init(allocator: std.mem.Allocator) PackageOptions {
        return PackageOptions{
            .args = std.ArrayList([]const u8).init(allocator),
        };
    }

    /// Releases all resources held by this PackageOptions.
    ///
    /// This must be called to avoid memory leaks when the PackageOptions
    /// is no longer needed. Frees the internal args ArrayList.
    pub fn deinit(self: *PackageOptions) void {
        self.args.deinit();
    }

    /// Appends a command-line argument to the options.
    ///
    /// Parameters:
    ///   - arg: The argument string to add (e.g., "--features=derive")
    ///
    /// Note: Silently ignores allocation failures.
    pub fn addArg(self: *PackageOptions, arg: []const u8) void {
        self.args.append(arg) catch {};
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
///   try cmd_args.packages.append("serde");
///   try cmd_args.manager_args.append("--features=derive");
/// ```
pub const CommandArgs = struct {
    /// List of package names to install, remove, or upgrade.
    packages: std.ArrayList([]const u8),
    /// Additional arguments specific to the package manager.
    manager_args: std.ArrayList([]const u8),

    /// Initializes a new CommandArgs instance.
    ///
    /// Parameters:
    ///   - allocator: Memory allocator for the internal lists
    ///
    /// Returns:
    ///   A new CommandArgs with initialized empty lists
    pub fn init(allocator: std.mem.Allocator) CommandArgs {
        return CommandArgs{
            .packages = std.ArrayList([]const u8).init(allocator),
            .manager_args = std.ArrayList([]const u8).init(allocator),
        };
    }

    /// Releases all resources held by this CommandArgs.
    ///
    /// Frees both the packages and manager_args lists.
    pub fn deinit(self: *CommandArgs) void {
        self.packages.deinit();
        self.manager_args.deinit();
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
    const lower = std.ascii.lowerString(name);
    if (std.mem.eql(u8, lower, "cargo")) return .cargo;
    if (std.mem.eql(u8, lower, "npm")) return .npm;
    if (std.mem.eql(u8, lower, "pnpm")) return .pnpm;
    if (std.mem.eql(u8, lower, "bun")) return .bun;
    if (std.mem.eql(u8, lower, "yarn")) return .yarn;
    if (std.mem.eql(u8, lower, "pip")) return .pip;
    if (std.mem.eql(u8, lower, "poetry")) return .poetry;
    if (std.mem.eql(u8, lower, "pdm")) return .pdm;
    return null;
}
