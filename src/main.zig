/// mg - Multi-Package Manager CLI
///
/// A cross-ecosystem package management tool written in Zig without third-party
/// dependencies. Supports Cargo, npm, pnpm, yarn, bun, pip, PDM, and Poetry.
///
/// Usage:
///   mg add <package>       - Add a package
///   mg remove <package>    - Remove a package
///   mg upgrade             - Upgrade all packages
///   mg fs <subcommand>     - File system operations
///
/// Options:
///   --dry-run, -d         - Preview command without executing
///   --help, -h            - Show this help message
const std = @import("std");
const App = @import("app.zig").App;

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.heap.page_allocator.free(args);

    if (args.len < 2) {
        // No arguments provided, show help
        const help = @import("cli/help.zig");
        help.printHelp();
        return;
    }

    try App.run(args);
}
