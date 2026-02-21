/// Application core module for mg.
///
/// This module provides the main application logic and command dispatching.
/// It serves as the central coordinator between CLI parsing and module execution.
const std = @import("std");
const cli = @import("cli/mod.zig");
const fs = @import("fs/mod.zig");
const pkgm = @import("pkgm/mod.zig");
const logger = @import("core/logger.zig");

/// Main application structure.
pub const App = struct {
    /// Runs the application with the given command-line arguments.
    ///
    /// Parameters:
    ///   - args: Command-line argument slice (including program name)
    ///
    /// Returns:
    ///   !void - May return errors from underlying operations
    pub fn run(args: []const [:0]u8) !void {
        // Parse command-line arguments
        const result = cli.parser.parse(args);

        // Dispatch based on parse result
        switch (result) {
            .help => cli.help.printHelp(),
            .fs => {
                // FS commands are handled within the parser
                // This arm is reached when fs command completes successfully
            },
            .pkg => try handlePackageCommand(args),
            .none => {
                // No valid command or help already shown
            },
        }
    }

    /// Handles package management commands.
    fn handlePackageCommand(args: []const [:0]u8) !void {
        if (args.len < 3) {
            logger.err("No package command specified\n", .{});
            return;
        }

        const action = args[2];
        const packages = if (args.len > 3) args[3..] else &[_][:0]u8{};

        try pkgm.executeCommand(action, packages, false);
    }
};
