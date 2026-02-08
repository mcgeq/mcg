/// Package manager interface module.
///
/// This module provides the unified interface for all package manager operations.
/// It combines detection, command registration, and execution into a simple API
/// that automatically handles the complexity of working with multiple package managers.
const std = @import("std");
const MgError = @import("../error.zig").MgError;
const ManagerType = @import("../types.zig").ManagerType;

pub const detect = @import("detect.zig");
pub const registry = @import("registry.zig");
pub const executor = @import("executor.zig");

/// Executes a package manager command for the detected project type.
///
/// This is the main entry point for package management operations. It:
///   1. Detects the package manager for the current project
///   2. Maps the action to the package manager's native command
///   3. Executes the command (or shows dry-run output)
///
/// Parameters:
///   - action: The action to perform (first character: a=add, r=remove, u=upgrade, etc.)
///   - packages: Slice of package names to operate on
///   - dry_run: If true, preview the command without executing
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
///   try pkgm.executeCommand("add","}, false);
///
/// &.{"lodash   // Dry-run upgrade (shows what would happen)
///   try pkgm.executeCommand("upgrade", &.{}, true);
/// ```
pub fn executeCommand(action: []const u8, packages: []const [:0]u8, dry_run: bool) MgError!void {
    const manager_type = detect.detectPackageManager() orelse {
        std.debug.print("No supported package manager detected\n", .{});
        return error.NoPackageManager;
    };

    const manager_name = registry.getManagerName(manager_type);
    std.debug.print("Using {s} package manager\n", .{manager_name});

    try executor.execute(manager_type, action, packages, dry_run);
}
