/// CLI help module.
///
/// This module provides help text output for the mg CLI.
const logger = @import("../core/logger.zig");

/// Prints the main help information to stdout.
///
/// Displays a summary of available commands, file system operations,
/// and command-line options for the mg CLI.
pub fn printHelp() void {
    logger.infoMulti(&.{
        "mg - Multi-package manager CLI",
        "Usage: mg [options] <command> [args]",
        "Commands: add, remove, upgrade, install, analyze",
        "FS Commands: fs create, fs remove, fs copy, fs move, fs list, fs read, fs write",
        "Options: --dry-run, --help",
    });
}

/// Prints the file system subcommand help.
pub fn printFsHelp() void {
    logger.infoMulti(&.{
        "Usage: mg fs <subcommand> [args]",
        "Subcommands: create(c,touch), remove(r), copy(y), move(m), list, read, write",
    });
}
