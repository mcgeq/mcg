/// File system operations module.
///
/// This module provides low-level file system operations for the mg CLI.
/// All functions support a dry-run mode that previews the operation without
/// actually executing it. The module handles file creation, deletion, copying,
/// moving, and reading/writing operations.
const std = @import("std");
const logger = @import("../logger.zig");

fn matchesWildcard(filename: []const u8, pattern: []const u8) bool {
    var i: usize = 0;
    var j: usize = 0;
    var last_star: ?usize = null;
    var last_match: usize = 0;

    while (i < filename.len) {
        if (j < pattern.len and (pattern[j] == filename[i] or pattern[j] == '?')) {
            i += 1;
            j += 1;
        } else if (j < pattern.len and pattern[j] == '*') {
            last_star = j;
            last_match = i;
            j += 1;
        } else if (last_star) |star| {
            last_match += 1;
            i = last_match;
            j = star + 1;
        } else {
            return false;
        }
    }

    while (j < pattern.len and pattern[j] == '*') {
        j += 1;
    }

    return j == pattern.len;
}

pub fn fsRemoveWildcard(pattern: []const u8, recursive: bool, dry_run: bool) !void {
    const dir = std.fs.path.dirname(pattern) orelse ".";
    const base_pattern = std.fs.path.basename(pattern);

    var search_dir = std.fs.cwd().openDir(dir, .{ .iterate = true }) catch {
        logger.err("Directory not found: {s}\n", .{dir});
        return;
    };
    defer search_dir.close();

    var matched_count: usize = 0;

    var iter = search_dir.iterate();
    while (iter.next() catch null) |entry| {
        if (matchesWildcard(entry.name, base_pattern)) {
            matched_count += 1;
            if (dry_run) {
                if (std.mem.eql(u8, dir, ".")) {
                    logger.debug("[dry-run] Remove: {s}\n", .{entry.name});
                } else {
                    logger.debug("[dry-run] Remove: {s}/{s}\n", .{ dir, entry.name });
                }
            } else {
                if (std.mem.eql(u8, dir, ".")) {
                    fsRemove(entry.name, recursive, false) catch {};
                } else {
                    const full_path = try std.fs.path.join(std.heap.page_allocator, &.{ dir, entry.name });
                    defer std.heap.page_allocator.free(full_path);
                    fsRemove(full_path, recursive, false) catch {};
                }
            }
        }
    }

    if (matched_count == 0) {
        logger.info("No files matched: {s}\n", .{pattern});
    }
}

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
        logger.debug("[dry-run] Create {s}: {s}\n", .{ if (is_dir) "directory" else "file", path });
        return;
    }

    if (is_dir) {
        std.fs.cwd().access(path, .{}) catch {
            std.fs.cwd().makePath(path) catch {
                logger.err("Failed to create directory: {s}\n", .{path});
                return;
            };
            logger.info("Created directory: {s}\n", .{path});
            return;
        };
        logger.info("Directory already exists: {s}\n", .{path});
    } else {
        std.fs.cwd().access(path, .{}) catch {
            const file = std.fs.cwd().createFile(path, .{}) catch {
                logger.err("Failed to create file: {s}\n", .{path});
                return;
            };
            file.close();
            logger.info("Created file: {s}\n", .{path});
            return;
        };
        logger.info("File already exists: {s}\n", .{path});
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
        logger.debug("[dry-run] Remove: {s}\n", .{path});
        return;
    }

    const exists = std.fs.cwd().openFile(path, .{}) catch |err| blk: {
        if (err == error.FileNotFound or err == error.PathNotFound) {
            logger.err("Path not found: {s}", .{path});
            return;
        }
        break :blk null;
    };
    if (exists) |f| {
        f.close();
    }

    if (recursive) {
        std.fs.cwd().deleteTree(path) catch |err| {
            logger.err("Failed to remove {s}: {s}\n", .{ path, @errorName(err) });
            return;
        };
    } else {
        std.fs.cwd().deleteFile(path) catch |err| {
            logger.err("Failed to remove {s}: {s}\n", .{ path, @errorName(err) });
            return;
        };
    }
    logger.info("Removed: {s}\n", .{path});
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
        logger.debug("[dry-run] Copy: {s} -> {s}\n", .{ src, dst });
        return;
    }

    std.fs.cwd().copyFile(src, std.fs.cwd(), dst, .{}) catch {
        logger.err("Source not found: {s}\n", .{src});
        return;
    };
    logger.info("Copied: {s} -> {s}\n", .{ src, dst });
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
        logger.debug("[dry-run] Copy {s}: {s} -> {s}\n", .{ if (recursive) "recursive" else "", src, dst });
        return;
    }

    const src_file = std.fs.cwd().openFile(src, .{}) catch null;
    if (src_file) |f| {
        f.close();
        std.fs.cwd().copyFile(src, std.fs.cwd(), dst, .{}) catch {
            logger.err("Failed to copy to: {s}\n", .{dst});
            return;
        };
        logger.info("Copied: {s} -> {s}\n", .{ src, dst });
    } else {
        if (recursive) {
            copyDirAll(src, dst) catch {
                logger.err("Source not found: {s}\n", .{src});
                return;
            };
            logger.info("Copied directory: {s} -> {s}\n", .{ src, dst });
        } else {
            logger.err("{s} is a directory, use --recursive\n", .{src});
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
        logger.debug("[dry-run] Create {s}: {s}\n", .{ if (is_dir) "directory" else "file", path });
        return;
    }

    if (is_dir) {
        std.fs.cwd().access(path, .{}) catch {
            std.fs.cwd().makePath(path) catch {
                logger.err("Failed to create directory: {s}\n", .{path});
                return;
            };
            logger.info("Created directory: {s}\n", .{path});
            return;
        };
        logger.info("Directory already exists: {s}\n", .{path});
    } else {
        std.fs.cwd().access(path, .{}) catch {
            const file = std.fs.cwd().createFile(path, .{}) catch |err| {
                if (err == error.FileNotFound and recursive) {
                    const parent = std.fs.path.dirname(path);
                    if (parent) |p| {
                        std.fs.cwd().makePath(p) catch {
                            logger.err("Failed to create parent directory: {s}\n", .{p});
                            return;
                        };
                        const f = std.fs.cwd().createFile(path, .{}) catch {
                            logger.err("Failed to create file: {s}\n", .{path});
                            return;
                        };
                        f.close();
                        logger.info("Created file: {s}\n", .{path});
                        return;
                    }
                }
                logger.err("Failed to create file: {s}\n", .{path});
                return;
            };
            file.close();
            logger.info("Created file: {s}\n", .{path});
            return;
        };
        logger.info("File already exists: {s}\n", .{path});
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
        logger.debug("[dry-run] Move: {s} -> {s}\n", .{ src, dst });
        return;
    }

    std.fs.cwd().rename(src, dst) catch {
        logger.err("Source not found: {s}\n", .{src});
        return;
    };
    logger.info("Moved: {s} -> {s}\n", .{ src, dst });
}

pub fn fsListWildcard(pattern: []const u8, dry_run: bool) !void {
    const dir = std.fs.path.dirname(pattern) orelse ".";
    const base_pattern = std.fs.path.basename(pattern);

    var search_dir = std.fs.cwd().openDir(dir, .{ .iterate = true }) catch {
        std.debug.print("[dry-run] List: {s} (dir not found)\n", .{pattern});
        return;
    };
    defer search_dir.close();

    var matched_count: usize = 0;

    const timestamp = std.time.timestamp();
    const tz_offset: i64 = 8 * 3600;
    const local_ts = timestamp + tz_offset;
    const seconds_since_midnight = @mod(local_ts, 86400);
    const hour = @as(u32, @intCast(@divTrunc(seconds_since_midnight, 3600)));
    const minute = @as(u32, @intCast(@divTrunc(@mod(seconds_since_midnight, 3600), 60)));
    const second = @as(u32, @intCast(@mod(seconds_since_midnight, 60)));

    std.debug.print("[{d:02}:{d:02}:{d:02}] INFO\n", .{ hour, minute, second });

    var iter = search_dir.iterate();
    while (iter.next() catch null) |entry| {
        if (matchesWildcard(entry.name, base_pattern)) {
            matched_count += 1;
            if (!dry_run) {
                const mark = if (entry.kind == .directory) "/" else "";
                std.debug.print("  {s}{s}\n", .{ entry.name, mark });
            }
        }
    }

    if (matched_count == 0) {
        std.debug.print("No files matched: {s}\n", .{pattern});
    }
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
        logger.debug("[dry-run] List: {s}\n", .{path});
        return;
    }

    var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch {
        logger.err("Path not found: {s}\n", .{path});
        return;
    };
    defer dir.close();

    logger.info("", .{});

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
        logger.debug("[dry-run] Exists check: {s}\n", .{path});
        return;
    }

    const file = std.fs.cwd().openFile(path, .{}) catch null;
    if (file) |f| {
        f.close();
        logger.info("{s} exists\n", .{path});
    } else {
        logger.info("{s} not found\n", .{path});
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
        logger.debug("[dry-run] Read: {s}\n", .{path});
        return;
    }

    const file = std.fs.cwd().openFile(path, .{}) catch {
        logger.err("File not found: {s}\n", .{path});
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
        logger.debug("[dry-run] Write {d} bytes to: {s}\n", .{ content.len, path });
        return;
    }

    const file = std.fs.cwd().createFile(path, .{}) catch {
        logger.err("Failed to create file: {s}\n", .{path});
        return;
    };
    defer file.close();
    file.writeAll(content) catch {};
    logger.info("Wrote {d} bytes to: {s}\n", .{ content.len, path });
}
