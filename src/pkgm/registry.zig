/// Package manager command registry.
///
/// This module maps short-hand commands to package-manager-specific commands.
/// It provides a unified interface for common operations across all supported
/// package managers, translating simple commands like "add" or "remove" into
/// the appropriate native commands for each ecosystem.
const ManagerType = @import("../types.zig").ManagerType;

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
        .poetry => "poetry",
        .pdm => "pdm",
    };
}

/// Maps a generic action to the package manager's native command.
///
/// This function translates simple action characters (a=add, r=remove, etc.)
/// into the appropriate command for each package manager. Different package
/// managers use different terminology for the same operations.
///
/// Supported Actions:
///   - 'a' or 'A': Add/install a package
///   - 'r' or 'R': Remove/uninstall a package
///   - 'u' or 'U': Update/upgrade packages
///   - 'i' or 'I': Install dependencies
///   - 'l' or 'L': List dependencies
///
/// Parameters:
///   - manager_type: The detected package manager type
///   - action: Single character representing the action (e.g., 'a', 'r')
///   - packages: Slice of package names (required for add/remove operations)
///
/// Returns:
///   The native command string, or null if the action requires packages but none provided
///
/// Command Mappings:
///   | Action | Cargo | npm/pnpm/bun/yarn | pip | poetry/pdm |
///   |--------|-------|-------------------|-----|------------|
///   | add    | add   | install           | install | add    |
///   | remove | remove| remove/uninstall  | uninstall| remove |
///   | update | update| update            | -       | -       |
///   | install| check | install           | install | -       |
///   | list   | tree  | list              | list    | list    |
pub fn getCommand(manager_type: ManagerType, action: []const u8, packages: []const [:0]u8) ?[]const u8 {
    const cmd = action[0];
    switch (cmd) {
        'a', 'A' => {
            if (packages.len == 0) return null;
            return switch (manager_type) {
                .cargo => "add",
                .npm, .pnpm, .bun, .yarn => "install",
                .pip => "install",
                .poetry, .pdm => "add",
            };
        },
        'r', 'R' => {
            if (packages.len == 0) return null;
            return switch (manager_type) {
                .cargo => "remove",
                .npm => "uninstall",
                .pnpm, .bun, .yarn => "remove",
                .pip => "uninstall",
                .poetry, .pdm => "remove",
            };
        },
        'u', 'U' => return "update",
        'i', 'I' => return switch (manager_type) {
            .cargo => "check",
            else => "install",
        },
        'l', 'L' => return switch (manager_type) {
            .cargo => "tree",
            .npm, .pnpm, .bun, .yarn, .pip, .poetry, .pdm => "list",
        },
        else => return null,
    }
    return null;
}
