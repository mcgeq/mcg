const std = @import("std");

pub const MgError = error{
    NoPackageManager,
    UnsupportedManager,
    CommandFailed,
    ManagerNotInstalled,
    ConfigParseFailed,
    ConfigReadFailed,
    InvalidPackageName,
    CurrentDirFailed,
    IoError,
    CreateDirFailed,
    CreateFileFailed,
    RemoveFailed,
    CopyFailed,
    MoveFailed,
    PathNotFound,
    LoggerInitFailed,
    CacheCorrupted,
    UnknownSubcommand,
    MissingSubcommand,
    UnknownOption,
    InvalidArgument,
};

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

pub fn formatErrorWithContext(err: MgError, writer: std.fs.File.Writer, context: []const u8) void {
    const prefix = switch (err) {
        .CommandFailed => "Command failed",
        .ManagerNotInstalled => "Manager not installed",
        else => "Error",
    };
    writer.print("{s}: {s}", .{ prefix, context }) catch {};
}
