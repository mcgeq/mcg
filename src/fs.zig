/// File system operations module.
///
/// This module provides low-level file system operations for the mg CLI.
/// All functions support a dry-run mode that previews the operation without
/// actually executing it. The module handles file creation, deletion, copying,
/// moving, and reading/writing operations.
const std = @import("std");

/// Creates a file or directory at the specified path.
///
/// Parameters:
///   - path: The file system path to create
///   - is_dir: If true, creates a directory; otherwise creates a file
///   - dry_run: If true, only prints the operation without executing
///
/// Returns:
///   void - Errors are printed and returned silently
///
/// Errors:
///   Returns on first error encountered, prints error message
pub fn fsCreate(path: []const u8, is_dir: bool, dry_run: bool) !void {
    if (dry_run) {
        std.debug.print("[dry-run] Create {s}: {s}\n", .{ if (is_dir) "directory" else "file", path });
        return;
    }

    if (is_dir) {
        std.fs.cwd().makePath(path) catch {
            std.debug.print("Error: Failed to create directory: {s}\n", .{path});
            return;
        };
        std.debug.print("Created directory: {s}\n", .{path});
    } else {
        const file = std.fs.cwd().createFile(path, .{}) catch {
            std.debug.print("Error: Failed to create file: {s}\n", .{path});
            return;
        };
        file.close();
        std.debug.print("Created file: {s}\n", .{path});
    }
}

/// Removes a file or directory at the specified path.
///
/// Parameters:
///   - path: The file system path to remove
///   - recursive: If true, removes directories recursively
///   - dry_run: If true, only prints the operation without executing
///
/// Note:
///   If the path doesn't exist, an error message is printed and operation stops.
///   On non-recursive mode, attempting to remove a directory will fail.
///
/// Errors:
///   Prints error and returns on failure
pub fn fsRemove(path: []const u8, recursive: bool, dry_run: bool) !void {
    if (dry_run) {
        std.debug.print("[dry-run] Remove: {s}\n", .{path});
        return;
    }

    const exists = std.fs.cwd().openFile(path, .{}) catch |err| blk: {
        if (err == error.FileNotFound or err == error.PathNotFound) {
            std.debug.print("Error: Path not found: {s}\n", .{path});
            return;
        }
        break :blk null;
    };
    if (exists) |f| {
        f.close();
    }

    if (recursive) {
        std.fs.cwd().deleteTree(path) catch |err| {
            std.debug.print("Error: Failed to remove {s}: {s}\n", .{ path, @errorName(err) });
            return;
        };
    } else {
        std.fs.cwd().deleteFile(path) catch |err| {
            std.debug.print("Error: Failed to remove {s}: {s}\n", .{ path, @errorName(err) });
            return;
        };
    }
    std.debug.print("Removed: {s}\n", .{path});
}

/// Copies a single file from source to destination.
///
/// This is a simple file copy operation that doesn't handle directories.
/// For directory copying with recursive support, use fsCopyExtended.
///
/// Parameters:
///   - src: Source file path
///   - dst: Destination file path
///   - dry_run: If true, only prints the operation without executing
pub fn fsCopy(src: []const u8, dst: []const u8, dry_run: bool) !void {
    if (dry_run) {
        std.debug.print("[dry-run] Copy: {s} -> {s}\n", .{ src, dst });
        return;
    }

    std.fs.cwd().copyFile(src, std.fs.cwd(), dst, .{}) catch {
        std.debug.print("Error: Source not found: {s}\n", .{src});
        return;
    };
    std.debug.print("Copied: {s} -> {s}\n", .{ src, dst });
}

/// Copies a file or directory with optional recursive directory support.
///
/// This extended version can copy both files and directories. For directories,
/// it checks if the source is a file first, falling back to directory copy
/// if recursive is true.
///
/// Parameters:
///   - src: Source file or directory path
///   - dst: Destination path
///   - recursive: If true, allows copying directories recursively
///   - dry_run: If true, only prints the operation without executing
///
/// Behavior:
///   - If src is a file: copies the file directly
///   - If src is a directory and recursive=true: calls copyDirAll
///   - If src is a directory and recursive=false: prints error
pub fn fsCopyExtended(src: []const u8, dst: []const u8, recursive: bool, dry_run: bool) !void {
    if (dry_run) {
        std.debug.print("[dry-run] Copy {s}: {s} -> {s}\n", .{ if (recursive) "recursive" else "", src, dst });
        return;
    }

    const src_file = std.fs.cwd().openFile(src, .{}) catch null;
    if (src_file) |f| {
        f.close();
        std.fs.cwd().copyFile(src, std.fs.cwd(), dst, .{}) catch {
            std.debug.print("Error: Failed to copy to: {s}\n", .{dst});
            return;
        };
        std.debug.print("Copied: {s} -> {s}\n", .{ src, dst });
    } else {
        if (recursive) {
            copyDirAll(src, dst) catch {
                std.debug.print("Error: Source not found: {s}\n", .{src});
                return;
            };
            std.debug.print("Copied directory: {s} -> {s}\n", .{ src, dst });
        } else {
            std.debug.print("Error: {s} is a directory, use --recursive\n", .{src});
        }
    }
}

/// Recursively copies a directory and all its contents.
///
/// Internal helper function that creates the destination directory and
/// iterates through source entries, copying files and recursing into subdirectories.
///
/// Parameters:
///   - src: Source directory path
///   - dst: Destination directory path
///
/// Note:
///   Silently continues on errors (non-strict error handling).
fn copyDirAll(src: []const u8, dst: []const u8) !void {
    var src_dir = std.fs.cwd().openDir(src, .{ .iterate = true }) catch return error.PathNotFound;
    defer src_dir.close();

    std.fs.cwd().makePath(dst) catch {};

    var iter = src_dir.iterate();
    while (iter.next() catch null) |entry| {
        const src_path = std.fs.path.join(std.heap.page_allocator, &.{ src, entry.name }) catch continue;
        defer std.heap.page_allocator.free(src_path);
        const dst_path = std.fs.path.join(std.heap.page_allocator, &.{ dst, entry.name }) catch continue;
        defer std.heap.page_allocator.free(dst_path);

        if (entry.kind == .directory) {
            copyDirAll(src_path, dst_path) catch {};
        } else if (entry.kind == .file) {
            std.fs.cwd().copyFile(src_path, std.fs.cwd(), dst_path, .{}) catch {};
        }
    }
}

/// Creates a file or directory with extended options.
///
/// Enhanced version of fsCreate that supports recursive parent directory
/// creation for files and directories.
///
/// Parameters:
///   - path: The file system path to create
///   - is_dir: If true, creates a directory; otherwise creates a file
///   - recursive: If true, creates parent directories as needed
///   - dry_run: If true, only prints the operation without executing
///
/// Behavior:
///   - For directories: always creates the full path
///   - For files with recursive=true: creates missing parent directories
///   - For files with recursive=false: fails if parent doesn't exist
pub fn fsCreateExtended(path: []const u8, is_dir: bool, recursive: bool, dry_run: bool) !void {
    if (dry_run) {
        std.debug.print("[dry-run] Create {s}: {s}\n", .{ if (is_dir) "directory" else "file", path });
        return;
    }

    if (is_dir) {
        std.fs.cwd().makePath(path) catch {
            std.debug.print("Error: Failed to create directory: {s}\n", .{path});
            return;
        };
        std.debug.print("Created directory: {s}\n", .{path});
    } else {
        const file = std.fs.cwd().createFile(path, .{}) catch |err| {
            if (err == error.FileNotFound and recursive) {
                const parent = std.fs.path.dirname(path);
                if (parent) |p| {
                    std.fs.cwd().makePath(p) catch {
                        std.debug.print("Error: Failed to create parent directory: {s}\n", .{p});
                        return;
                    };
                    const f = std.fs.cwd().createFile(path, .{}) catch {
                        std.debug.print("Error: Failed to create file: {s}\n", .{path});
                        return;
                    };
                    f.close();
                    std.debug.print("Created file: {s}\n", .{path});
                    return;
                }
            }
            std.debug.print("Error: Failed to create file: {s}\n", .{path});
            return;
        };
        file.close();
        std.debug.print("Created file: {s}\n", .{path});
    }
}

/// Moves or renames a file or directory.
///
/// This operation is atomic on the same file system and can be used
/// for both moving files between directories and renaming within a directory.
///
/// Parameters:
///   - src: Source file or directory path
///   - dst: Destination file or directory path
///   - dry_run: If true, only prints the operation without executing
pub fn fsMove(src: []const u8, dst: []const u8, dry_run: bool) !void {
    if (dry_run) {
        std.debug.print("[dry-run] Move: {s} -> {s}\n", .{ src, dst });
        return;
    }

    std.fs.cwd().rename(src, dst) catch {
        std.debug.print("Error: Source not found: {s}\n", .{src});
        return;
    };
    std.debug.print("Moved: {s} -> {s}\n", .{ src, dst });
}

/// Lists the contents of a directory.
///
/// Parameters:
///   - path: The directory path to list (defaults to "." if empty)
///   - dry_run: If true, only prints the path without listing contents
///
/// Output Format:
///   Directories are suffixed with "/" for easy identification.
///   Example output:
///   ```
///   src/
///   tests/
///   main.zig
///   build.zig
///   ```
pub fn fsList(path: []const u8, dry_run: bool) !void {
    if (dry_run) {
        std.debug.print("[dry-run] List: {s}\n", .{path});
        return;
    }

    var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch {
        std.debug.print("Error: Path not found: {s}\n", .{path});
        return;
    };
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        const mark = if (entry.kind == .directory) "/" else "";
        std.debug.print("  {s}{s}\n", .{ entry.name, mark });
    }
}

/// Checks if a file or directory exists at the specified path.
///
/// Parameters:
///   - path: The file system path to check
///   - dry_run: If true, only prints the check operation
///
/// Output:
///   Prints "exists" or "not found" message
pub fn fsExists(path: []const u8, dry_run: bool) void {
    if (dry_run) {
        std.debug.print("[dry-run] Exists check: {s}\n", .{path});
        return;
    }

    const file = std.fs.cwd().openFile(path, .{}) catch null;
    if (file) |f| {
        f.close();
        std.debug.print("{s} exists\n", .{path});
    } else {
        std.debug.print("{s} not found\n", .{path});
    }
}

/// Reads the entire contents of a file and prints it to stdout.
///
/// Parameters:
///   - path: The file path to read
///   - dry_run: If true, only prints the read operation
///
/// Note:
///   Allocates memory to read the entire file into memory.
pub fn fsRead(path: []const u8, dry_run: bool) !void {
    if (dry_run) {
        std.debug.print("[dry-run] Read: {s}\n", .{path});
        return;
    }

    const file = std.fs.cwd().openFile(path, .{}) catch {
        std.debug.print("Error: File not found: {s}\n", .{path});
        return;
    };
    defer file.close();

    const content = file.readToEndAlloc(std.heap.page_allocator, std.math.maxInt(usize)) catch "";
    defer std.heap.page_allocator.free(content);
    std.debug.print("{s}", .{content});
}

/// Writes content to a file, creating it if it doesn't exist.
///
/// Parameters:
///   - path: The file path to write to
///   - content: The content to write to the file
///   - dry_run: If true, only prints the write operation with byte count
///
/// Behavior:
///   - Creates the file if it doesn't exist
///   - Overwrites the file if it exists
///   - Truncates existing content
pub fn fsWrite(path: []const u8, content: []const u8, dry_run: bool) !void {
    if (dry_run) {
        std.debug.print("[dry-run] Write {d} bytes to: {s}\n", .{ content.len, path });
        return;
    }

    const file = std.fs.cwd().createFile(path, .{}) catch {
        std.debug.print("Error: Failed to create file: {s}\n", .{path});
        return;
    };
    defer file.close();
    file.writeAll(content) catch {};
    std.debug.print("Wrote {d} bytes to: {s}\n", .{ content.len, path });
}
