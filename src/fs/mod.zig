/// File system commands module.
///
/// This module provides the high-level interface for file system operations.
/// It delegates to the commands module for parsing and dispatching file system
/// subcommands. All operations support dry-run mode for previewing actions.
const fs = @import("../fs.zig");
pub const commands = @import("commands.zig");

/// Handles a file system subcommand by parsing arguments and dispatching to the appropriate handler.
///
/// This is the main entry point for fs subcommand processing. It receives
/// the subcommand and its arguments, then delegates to the commands module.
///
/// Parameters:
///   - cmd: The subcommand string (e.g., "create", "remove", "copy")
///   - args: Slice of argument strings for the subcommand
///   - dry_run: If true, preview operations without executing
///
/// Returns:
///   void - Errors are caught and printed internally
///
/// Note:
///   Unknown subcommands result in an error message printed to stderr.
pub fn handleCommand(cmd: []const u8, args: []const [:0]u8, dry_run: bool) !void {
    try commands.handleCommand(cmd, args, dry_run);
}
