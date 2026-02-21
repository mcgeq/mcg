/// Error types for the mg multi-package manager CLI.
///
/// All error types are defined as tagged union errors that may be returned
/// by various operations throughout the application. Error formatting functions
/// provide user-friendly messages for each error type.
const std = @import("std");

/// Represents all possible errors that can occur during mg operations.
///
/// Error Categories:
///   - Package Manager Errors: NoPackageManager, UnsupportedManager, ManagerNotInstalled
///   - Command Errors: CommandFailed, UnknownSubcommand, MissingSubcommand
///   - Configuration Errors: ConfigParseFailed, ConfigReadFailed
///   - File System Errors: CreateDirFailed, CreateFileFailed, RemoveFailed, CopyFailed, MoveFailed, PathNotFound
///   - Validation Errors: InvalidPackageName, InvalidArgument
///   - System Errors: IoError, CurrentDirFailed, LoggerInitFailed, CacheCorrupted
pub const MgError = error{
    /// No supported package manager was detected in the current directory.
    /// This occurs when the project doesn't contain any recognized lock files.
    NoPackageManager,
    /// The detected package manager is not supported by mg.
    UnsupportedManager,
    /// The package manager command failed to execute successfully.
    CommandFailed,
    /// The package manager executable is not found in the system PATH.
    ManagerNotInstalled,
    /// Failed to parse the configuration file content.
    ConfigParseFailed,
    /// Failed to read the configuration file from disk.
    ConfigReadFailed,
    /// The provided package name is invalid (empty or contains invalid characters).
    InvalidPackageName,
    /// Failed to get the current working directory.
    CurrentDirFailed,
    /// A generic I/O error occurred during file operations.
    IoError,
    /// Failed to create a directory at the specified path.
    CreateDirFailed,
    /// Failed to create a file at the specified path.
    CreateFileFailed,
    /// Failed to remove the file or directory at the specified path.
    RemoveFailed,
    /// Failed to copy a file or directory to the destination.
    CopyFailed,
    /// Failed to move or rename a file or directory.
    MoveFailed,
    /// The specified path does not exist.
    PathNotFound,
    /// Failed to initialize the logging system.
    LoggerInitFailed,
    /// The cache file is corrupted or contains invalid data.
    CacheCorrupted,
    /// An unknown subcommand was provided.
    UnknownSubcommand,
    /// A required subcommand was not provided.
    MissingSubcommand,
    /// An unknown command-line option was provided.
    UnknownOption,
    /// The provided argument is invalid for the operation.
    InvalidArgument,
};

/// Formats an MgError to a human-readable message and writes it to the provided writer.
///
/// This function maps each error type to a user-friendly message that explains
/// what went wrong and potentially how to fix it.
///
/// Parameters:
///   - err: The error to format
///   - writer: The file writer to output the formatted message
///
/// Example:
///   ```zig
///   var file = try std.fs.cwd().createFile("output.txt", .{});
///   defer file.close();
///   formatError(error.NoPackageManager, file.writer()) catch {};
///   ```
pub fn formatError(err: MgError, writer: std.fs.File.Writer) void {
    const msg = switch (err) {
        .NoPackageManager => "No supported package manager detected in current directory",
        .UnsupportedManager => "Unsupported package manager",
        .CommandFailed => "Command execution failed",
        .ManagerNotInstalled => "Package manager not found in PATH",
        .ConfigParseFailed => "Failed to parse configuration file",
        .ConfigReadFailed => "Failed to read configuration file",
        .InvalidPackageName => "Invalid package name",
        .CurrentDirFailed => "Failed to get current directory",
        .IoError => "I/O error occurred",
        .CreateDirFailed => "Failed to create directory",
        .CreateFileFailed => "Failed to create file",
        .RemoveFailed => "Failed to remove path",
        .CopyFailed => "Failed to copy file or directory",
        .MoveFailed => "Failed to move file or directory",
        .PathNotFound => "Path not found",
        .LoggerInitFailed => "Failed to initialize logger",
        .CacheCorrupted => "Cache file is corrupted",
        .UnknownSubcommand => "Unknown subcommand",
        .MissingSubcommand => "Missing subcommand",
        .UnknownOption => "Unknown option",
        .InvalidArgument => "Invalid argument",
        else => "Unknown error",
    };
    writer.writeAll(msg) catch {};
}

/// Formats an MgError with additional context information.
///
/// This variant of formatError prepends a context-specific prefix to provide
/// more detailed error information when multiple operations might fail.
///
/// Parameters:
///   - err: The error to format
///   - writer: The file writer to output the formatted message
///   - context: Additional context information about where/how the error occurred
///
/// Example:
///   ```zig
///   formatErrorWithContext(error.CommandFailed, writer, "cargo add serde");
///   // Output: "Command failed: cargo add serde"
/// ```
pub fn formatErrorWithContext(err: MgError, writer: std.fs.File.Writer, context: []const u8) void {
    const prefix = switch (err) {
        .CommandFailed => "Command failed",
        .ManagerNotInstalled => "Manager not installed",
        else => "Error",
    };
    writer.print("{s}: {s}", .{ prefix, context }) catch {};
}
