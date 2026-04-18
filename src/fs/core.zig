/// File system operations module.
///
/// This module provides low-level file system operations for the mg CLI.
/// All functions support a dry-run mode that previews the operation without
/// actually executing it. The module handles file creation, deletion, copying,
/// moving, and reading/writing operations.
const std = @import("std");
const logger = @import("../core/logger.zig");
const runtime = @import("../core/runtime.zig");

fn currentIo() std.Io {
    return runtime.get().io;
}

fn cwd() std.Io.Dir {
    return std.Io.Dir.cwd();
}

const ScopedDir = struct {
    dir: std.Io.Dir,
    needs_close: bool = false,

    fn close(self: *@This(), io: std.Io) void {
        if (self.needs_close) {
            self.dir.close(io);
        }
    }
};

fn openBaseDir(dry_run: bool) !ScopedDir {
    if (dry_run) {
        return .{ .dir = cwd() };
    }

    if (runtime.getFsCwd()) |path| {
        return .{
            .dir = try cwd().openDir(currentIo(), path, .{}),
            .needs_close = true,
        };
    }

    return .{ .dir = cwd() };
}

fn openBaseDirOrReport(dry_run: bool) ?ScopedDir {
    return openBaseDir(dry_run) catch |err| {
        if (runtime.getFsCwd()) |path| {
            logger.err("Failed to open fs cwd {s}: {s}\n", .{ path, @errorName(err) });
        } else {
            logger.err("Failed to open current directory: {s}\n", .{@errorName(err)});
        }
        return null;
    };
}

const PathKind = enum {
    missing,
    file,
    directory,
    other,
};

const ParentPathStatus = enum {
    ready,
    missing,
    not_directory,
    other,
};

const MoveFailure = enum {
    source_missing,
    destination_parent_missing,
    destination_parent_not_directory,
    destination_existing_directory,
    destination_existing_file,
    destination_dir_not_empty,
    cross_device,
    permission_denied,
    path_component_not_directory,
    other,
};

const WildcardSearchPlan = struct {
    root_path: []const u8,
    relative_pattern: []const u8,
    recursive: bool,

    fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.root_path);
        allocator.free(self.relative_pattern);
    }
};

const WildcardMatch = struct {
    path: []const u8,
    display_path: []const u8,
    kind: std.Io.File.Kind,
};

fn detectPathKindInDir(dir: std.Io.Dir, io: std.Io, path: []const u8) PathKind {
    const stat = dir.statFile(io, path, .{}) catch |err| return switch (err) {
        error.FileNotFound => .missing,
        else => .other,
    };

    return switch (stat.kind) {
        .file => .file,
        .directory => .directory,
        else => .other,
    };
}

fn destinationParentStatusInDir(dir: std.Io.Dir, io: std.Io, path: []const u8) ParentPathStatus {
    const parent = std.fs.path.dirname(path) orelse return .ready;
    if (parent.len == 0 or std.mem.eql(u8, parent, ".")) return .ready;

    return switch (detectPathKindInDir(dir, io, parent)) {
        .directory => .ready,
        .missing => .missing,
        .file => .not_directory,
        .other => .other,
    };
}

fn reportDestinationParentStatus(path: []const u8, status: ParentPathStatus) void {
    const parent = std.fs.path.dirname(path) orelse return;
    if (parent.len == 0 or std.mem.eql(u8, parent, ".")) return;

    switch (status) {
        .ready => {},
        .missing => logger.err("Destination parent directory not found: {s}\n", .{parent}),
        .not_directory => logger.err("Destination parent is not a directory: {s}\n", .{parent}),
        .other => logger.err("Failed to inspect destination parent: {s}\n", .{parent}),
    }
}

fn createParentDirPathInDir(dir: std.Io.Dir, io: std.Io, path: []const u8) !void {
    const parent = std.fs.path.dirname(path) orelse return;
    if (parent.len == 0 or std.mem.eql(u8, parent, ".")) return;
    try dir.createDirPath(io, parent);
}

fn isPathSeparator(byte: u8) bool {
    return byte == '/' or byte == '\\';
}

const PathSegment = struct {
    segment: []const u8,
    rest: []const u8,
};

fn nextPathSegment(path: []const u8) ?PathSegment {
    var start: usize = 0;
    while (start < path.len and isPathSeparator(path[start])) : (start += 1) {}
    if (start >= path.len) return null;

    var end = start;
    while (end < path.len and !isPathSeparator(path[end])) : (end += 1) {}
    return .{
        .segment = path[start..end],
        .rest = path[end..],
    };
}

fn matchesPathPattern(path: []const u8, pattern: []const u8) bool {
    const pattern_segment = nextPathSegment(pattern) orelse return nextPathSegment(path) == null;
    const path_segment = nextPathSegment(path) orelse {
        var remaining_pattern = pattern;
        while (nextPathSegment(remaining_pattern)) |segment| {
            if (!std.mem.eql(u8, segment.segment, "**")) return false;
            remaining_pattern = segment.rest;
        }
        return true;
    };

    if (std.mem.eql(u8, pattern_segment.segment, "**")) {
        return matchesPathPattern(path, pattern_segment.rest) or
            matchesPathPattern(path_segment.rest, pattern);
    }

    if (!matchesWildcard(path_segment.segment, pattern_segment.segment)) return false;
    return matchesPathPattern(path_segment.rest, pattern_segment.rest);
}

fn joinPatternSegmentsNormalized(
    allocator: std.mem.Allocator,
    segments: []const []const u8,
) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    for (segments, 0..) |segment, idx| {
        if (idx > 0) try out.append(allocator, '/');
        try out.appendSlice(allocator, segment);
    }

    return out.toOwnedSlice(allocator);
}

fn buildWildcardSearchPlan(
    allocator: std.mem.Allocator,
    pattern: []const u8,
) !WildcardSearchPlan {
    var segments: std.ArrayList([]const u8) = .empty;
    defer segments.deinit(allocator);

    var tokenizer = std.mem.tokenizeAny(u8, pattern, "/\\");
    while (tokenizer.next()) |segment| {
        try segments.append(allocator, segment);
    }

    if (segments.items.len == 0) return error.PathNotFound;

    var root_segment_count: usize = 0;
    while (root_segment_count < segments.items.len) : (root_segment_count += 1) {
        if (std.mem.indexOfAny(u8, segments.items[root_segment_count], "*?") != null) break;
    }

    const root_path = if (root_segment_count == 0)
        try allocator.dupe(u8, ".")
    else
        try std.fs.path.join(allocator, segments.items[0..root_segment_count]);
    errdefer allocator.free(root_path);

    const relative_segments = segments.items[root_segment_count..];
    if (relative_segments.len == 0) return error.PathNotFound;

    const relative_pattern = try joinPatternSegmentsNormalized(allocator, relative_segments);
    return .{
        .root_path = root_path,
        .relative_pattern = relative_pattern,
        .recursive = std.mem.indexOfAny(u8, relative_pattern, "/\\") != null,
    };
}

fn joinRootedRelativePath(
    allocator: std.mem.Allocator,
    root_path: []const u8,
    relative_path: []const u8,
) ![]const u8 {
    const joined = if (std.mem.eql(u8, root_path, "."))
        try allocator.dupe(u8, relative_path)
    else
        try std.fs.path.join(allocator, &.{ root_path, relative_path });

    normalizePathSeparatorsInPlace(joined);
    return joined;
}

fn normalizePathSeparatorsInPlace(path: []u8) void {
    for (path) |*byte| {
        if (byte.* == '\\') byte.* = '/';
    }
}

fn dupeNormalizedPath(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const dup = try allocator.dupe(u8, path);
    normalizePathSeparatorsInPlace(dup);
    return dup;
}

fn freeWildcardMatches(allocator: std.mem.Allocator, matches: *std.ArrayList(WildcardMatch)) void {
    for (matches.items) |match| {
        allocator.free(match.path);
        allocator.free(match.display_path);
    }
    matches.deinit(allocator);
}

fn collectWildcardMatchesInDir(
    allocator: std.mem.Allocator,
    dir: std.Io.Dir,
    io: std.Io,
    pattern: []const u8,
) !std.ArrayList(WildcardMatch) {
    var plan = try buildWildcardSearchPlan(allocator, pattern);
    defer plan.deinit(allocator);

    var matches: std.ArrayList(WildcardMatch) = .empty;
    errdefer freeWildcardMatches(allocator, &matches);

    var search_dir = dir.openDir(io, plan.root_path, .{ .iterate = true }) catch return error.PathNotFound;
    defer search_dir.close(io);

    if (plan.recursive) {
        var walker = try search_dir.walk(allocator);
        defer walker.deinit();

        while (try walker.next(io)) |entry| {
            if (!matchesPathPattern(entry.path, plan.relative_pattern)) continue;

            try matches.append(allocator, .{
                .path = try joinRootedRelativePath(allocator, plan.root_path, entry.path),
                .display_path = try dupeNormalizedPath(allocator, entry.path),
                .kind = entry.kind,
            });
        }
    } else {
        var iter = search_dir.iterate();
        while (try iter.next(io)) |entry| {
            if (!matchesWildcard(entry.name, plan.relative_pattern)) continue;

            try matches.append(allocator, .{
                .path = try joinRootedRelativePath(allocator, plan.root_path, entry.name),
                .display_path = try allocator.dupe(u8, entry.name),
                .kind = entry.kind,
            });
        }
    }

    return matches;
}

fn classifyMoveFailureInDir(
    dir: std.Io.Dir,
    io: std.Io,
    src: []const u8,
    dst: []const u8,
    err: anyerror,
) MoveFailure {
    if (detectPathKindInDir(dir, io, src) == .missing) return .source_missing;

    return switch (destinationParentStatusInDir(dir, io, dst)) {
        .missing => .destination_parent_missing,
        .not_directory => .destination_parent_not_directory,
        .other => .other,
        .ready => switch (err) {
            error.IsDir => .destination_existing_directory,
            error.NotDir => switch (detectPathKindInDir(dir, io, dst)) {
                .file => .destination_existing_file,
                else => .path_component_not_directory,
            },
            error.DirNotEmpty => .destination_dir_not_empty,
            error.CrossDevice => .cross_device,
            error.AccessDenied, error.PermissionDenied, error.ReadOnlyFileSystem => .permission_denied,
            else => .other,
        },
    };
}

fn reportMoveFailure(src: []const u8, dst: []const u8, failure: MoveFailure, err: anyerror) void {
    switch (failure) {
        .source_missing => logger.err("Source not found: {s}\n", .{src}),
        .destination_parent_missing => reportDestinationParentStatus(dst, .missing),
        .destination_parent_not_directory => reportDestinationParentStatus(dst, .not_directory),
        .destination_existing_directory => logger.err("Destination is an existing directory: {s}\n", .{dst}),
        .destination_existing_file => logger.err("Destination is an existing file: {s}\n", .{dst}),
        .destination_dir_not_empty => logger.err("Destination directory is not empty: {s}\n", .{dst}),
        .cross_device => logger.err("Cannot move across file systems: {s} -> {s}\n", .{ src, dst }),
        .permission_denied => logger.err("Permission denied while moving {s} -> {s}: {s}\n", .{ src, dst, @errorName(err) }),
        .path_component_not_directory => logger.err("A path component is not a directory while moving {s} -> {s}\n", .{ src, dst }),
        .other => logger.err("Failed to move {s} -> {s}: {s}\n", .{ src, dst, @errorName(err) }),
    }
}

fn fsRemoveInDir(
    dir: std.Io.Dir,
    io: std.Io,
    path: []const u8,
    recursive: bool,
    dry_run: bool,
) !void {
    if (dry_run) {
        logger.info("[dry-run] Remove: {s}\n", .{path});
        return;
    }

    switch (detectPathKindInDir(dir, io, path)) {
        .missing => {
            logger.err("Path not found: {s}\n", .{path});
            return;
        },
        .directory => {
            if (recursive) {
                dir.deleteTree(io, path) catch |err| {
                    logger.err("Failed to remove {s}: {s}\n", .{ path, @errorName(err) });
                    return;
                };
            } else {
                dir.deleteDir(io, path) catch |err| {
                    logger.err("Failed to remove {s}: {s} (use --recursive to remove directory and contents)\n", .{ path, @errorName(err) });
                    return;
                };
            }
        },
        .file => {
            dir.deleteFile(io, path) catch |err| {
                logger.err("Failed to remove {s}: {s}\n", .{ path, @errorName(err) });
                return;
            };
        },
        .other => {
            logger.err("Failed to inspect path before removal: {s}\n", .{path});
            return;
        },
    }
    logger.info("Removed: {s}\n", .{path});
}

fn copyDirAllInDir(dir: std.Io.Dir, io: std.Io, src: []const u8, dst: []const u8) !void {
    var src_dir = dir.openDir(io, src, .{ .iterate = true }) catch return error.PathNotFound;
    defer src_dir.close(io);

    try dir.createDirPath(io, dst);

    var iter = src_dir.iterate();
    while (try iter.next(io)) |entry| {
        const src_path = try std.fs.path.join(std.heap.page_allocator, &.{ src, entry.name });
        defer std.heap.page_allocator.free(src_path);
        const dst_path = try std.fs.path.join(std.heap.page_allocator, &.{ dst, entry.name });
        defer std.heap.page_allocator.free(dst_path);

        if (entry.kind == .directory) {
            try copyDirAllInDir(dir, io, src_path, dst_path);
        } else if (entry.kind == .file) {
            try dir.copyFile(src_path, dir, dst_path, io, .{});
        }
    }
}

fn fsCopyExtendedInDir(
    dir: std.Io.Dir,
    io: std.Io,
    src: []const u8,
    dst: []const u8,
    recursive: bool,
    dry_run: bool,
) !void {
    if (dry_run) {
        logger.info("[dry-run] {s}: {s} -> {s}\n", .{
            if (recursive) "Copy recursive" else "Copy",
            src,
            dst,
        });
        return;
    }

    switch (detectPathKindInDir(dir, io, src)) {
        .missing => {
            logger.err("Source not found: {s}\n", .{src});
            return;
        },
        .directory => {
            if (!recursive) {
                logger.err("{s} is a directory, use --recursive\n", .{src});
                return;
            }

            copyDirAllInDir(dir, io, src, dst) catch |err| {
                logger.err("Failed to copy {s} -> {s}: {s}\n", .{ src, dst, @errorName(err) });
                return;
            };
            logger.info("Copied directory: {s} -> {s}\n", .{ src, dst });
        },
        .file => {
            const parent_status = destinationParentStatusInDir(dir, io, dst);
            if (parent_status != .ready) {
                reportDestinationParentStatus(dst, parent_status);
                return;
            }

            dir.copyFile(src, dir, dst, io, .{}) catch |err| {
                logger.err("Failed to copy {s} -> {s}: {s}\n", .{ src, dst, @errorName(err) });
                return;
            };
            logger.info("Copied: {s} -> {s}\n", .{ src, dst });
        },
        .other => {
            logger.err("Failed to inspect source path: {s}\n", .{src});
            return;
        },
    }
}

fn fsCreateExtendedInDir(
    dir: std.Io.Dir,
    io: std.Io,
    path: []const u8,
    is_dir: bool,
    recursive: bool,
    dry_run: bool,
) !void {
    if (dry_run) {
        logger.info("[dry-run] Create {s}: {s}\n", .{ if (is_dir) "directory" else "file", path });
        return;
    }

    if (is_dir) {
        dir.access(io, path, .{}) catch {
            dir.createDirPath(io, path) catch {
                logger.err("Failed to create directory: {s}\n", .{path});
                return;
            };
            logger.info("Created directory: {s}\n", .{path});
            return;
        };
        logger.info("Directory already exists: {s}\n", .{path});
    } else {
        dir.access(io, path, .{}) catch {
            const file = dir.createFile(io, path, .{}) catch |err| {
                if (err == error.FileNotFound and recursive) {
                    createParentDirPathInDir(dir, io, path) catch {
                        const parent_path = std.fs.path.dirname(path) orelse path;
                        logger.err("Failed to create parent directory: {s}\n", .{parent_path});
                        return;
                    };
                    const created_file = dir.createFile(io, path, .{}) catch {
                        logger.err("Failed to create file: {s}\n", .{path});
                        return;
                    };
                    created_file.close(io);
                    logger.info("Created file: {s}\n", .{path});
                    return;
                }
                logger.err("Failed to create file: {s}\n", .{path});
                return;
            };
            file.close(io);
            logger.info("Created file: {s}\n", .{path});
            return;
        };
        logger.info("File already exists: {s}\n", .{path});
    }
}

fn fsMoveInDir(
    dir: std.Io.Dir,
    io: std.Io,
    src: []const u8,
    dst: []const u8,
    dry_run: bool,
) !void {
    if (dry_run) {
        logger.info("[dry-run] Move: {s} -> {s}\n", .{ src, dst });
        return;
    }

    dir.rename(src, dir, dst, io) catch |err| {
        const failure = classifyMoveFailureInDir(dir, io, src, dst, err);
        reportMoveFailure(src, dst, failure, err);
        return;
    };
    logger.info("Moved: {s} -> {s}\n", .{ src, dst });
}

fn pathExistsInDir(dir: std.Io.Dir, io: std.Io, path: []const u8) bool {
    dir.access(io, path, .{}) catch return false;
    return true;
}

fn readFileAllocInDir(
    dir: std.Io.Dir,
    io: std.Io,
    allocator: std.mem.Allocator,
    path: []const u8,
) ![]u8 {
    const file = dir.openFile(io, path, .{}) catch return error.FileNotFound;
    defer file.close(io);

    var read_buf: [4096]u8 = undefined;
    var reader = file.reader(io, &read_buf);
    return reader.interface.allocRemaining(allocator, .unlimited);
}

fn fsWriteInDir(
    dir: std.Io.Dir,
    io: std.Io,
    path: []const u8,
    content: []const u8,
    dry_run: bool,
) !void {
    if (dry_run) {
        logger.info("[dry-run] Write {d} bytes to: {s}\n", .{ content.len, path });
        return;
    }

    const parent_status = destinationParentStatusInDir(dir, io, path);
    if (parent_status != .ready) {
        reportDestinationParentStatus(path, parent_status);
        return;
    }

    const file = dir.createFile(io, path, .{}) catch {
        logger.err("Failed to create file: {s}\n", .{path});
        return;
    };
    defer file.close(io);

    var writer_buf: [1024]u8 = undefined;
    var writer = file.writer(io, &writer_buf);
    writer.interface.writeAll(content) catch {};
    writer.interface.flush() catch {};
    logger.info("Wrote {d} bytes to: {s}\n", .{ content.len, path });
}

fn writeStdoutBytes(bytes: []const u8) void {
    runtime.writeStdout(bytes);
}

fn appendRenderedListOutput(
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    lines: []const []const u8,
) !void {
    for (lines) |line| {
        try out.appendSlice(allocator, "  ");
        try out.appendSlice(allocator, line);
        try out.append(allocator, '\n');
    }
}

fn renderListOutput(
    allocator: std.mem.Allocator,
    lines: []const []const u8,
) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    try appendRenderedListOutput(&out, allocator, lines);
    return out.toOwnedSlice(allocator);
}

fn renderReadOutput(content: []const u8) []const u8 {
    return content;
}

fn writeStdoutLines(lines: []const []const u8) void {
    if (lines.len == 0) return;

    const rendered = renderListOutput(std.heap.page_allocator, lines) catch return;
    defer std.heap.page_allocator.free(rendered);
    writeStdoutBytes(rendered);
}

fn freeOwnedLines(allocator: std.mem.Allocator, lines: *std.ArrayList([]const u8)) void {
    for (lines.items) |line| allocator.free(line);
    lines.deinit(allocator);
}

fn formatListEntry(
    allocator: std.mem.Allocator,
    entry_name: []const u8,
    is_dir: bool,
) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}{s}", .{
        entry_name,
        if (is_dir) "/" else "",
    });
}

fn collectListLines(
    allocator: std.mem.Allocator,
    dir: std.Io.Dir,
    io: std.Io,
    pattern: ?[]const u8,
) !std.ArrayList([]const u8) {
    var lines: std.ArrayList([]const u8) = .empty;
    errdefer freeOwnedLines(allocator, &lines);

    var iter_dir = try dir.openDir(io, ".", .{ .iterate = true });
    defer iter_dir.close(io);

    var iter = iter_dir.iterate();
    while (try iter.next(io)) |entry| {
        if (pattern) |glob| {
            if (!matchesWildcard(entry.name, glob)) continue;
        }

        try lines.append(allocator, try formatListEntry(
            allocator,
            entry.name,
            entry.kind == .directory,
        ));
    }

    return lines;
}

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
    const io = currentIo();
    var base_dir = openBaseDirOrReport(dry_run) orelse return;
    defer base_dir.close(io);

    var matches = collectWildcardMatchesInDir(std.heap.page_allocator, base_dir.dir, io, pattern) catch |err| {
        switch (err) {
            error.PathNotFound => logger.err("Directory not found: {s}\n", .{pattern}),
            else => logger.err("Failed to resolve wildcard pattern {s}: {s}\n", .{ pattern, @errorName(err) }),
        }
        return;
    };
    defer freeWildcardMatches(std.heap.page_allocator, &matches);

    if (matches.items.len == 0) {
        logger.info("No files matched: {s}\n", .{pattern});
        return;
    }

    for (matches.items) |match| {
        if (dry_run) {
            logger.info("[dry-run] Remove: {s}\n", .{match.path});
        } else {
            try fsRemoveInDir(base_dir.dir, io, match.path, recursive, false);
        }
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
    const io = currentIo();
    var base_dir = openBaseDirOrReport(dry_run) orelse return;
    defer base_dir.close(io);
    return fsCreateExtendedInDir(base_dir.dir, io, path, is_dir, false, dry_run);
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
    const io = currentIo();
    var base_dir = openBaseDirOrReport(dry_run) orelse return;
    defer base_dir.close(io);
    return fsRemoveInDir(base_dir.dir, io, path, recursive, dry_run);
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
    const io = currentIo();
    var base_dir = openBaseDirOrReport(dry_run) orelse return;
    defer base_dir.close(io);
    return fsCopyExtendedInDir(base_dir.dir, io, src, dst, false, dry_run);
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
    const io = currentIo();
    var base_dir = openBaseDirOrReport(dry_run) orelse return;
    defer base_dir.close(io);
    return fsCopyExtendedInDir(base_dir.dir, io, src, dst, recursive, dry_run);
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
    const io = currentIo();
    var base_dir = openBaseDirOrReport(dry_run) orelse return;
    defer base_dir.close(io);
    return fsCreateExtendedInDir(base_dir.dir, io, path, is_dir, recursive, dry_run);
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
    const io = currentIo();
    var base_dir = openBaseDirOrReport(dry_run) orelse return;
    defer base_dir.close(io);
    return fsMoveInDir(base_dir.dir, io, src, dst, dry_run);
}

pub fn fsListWildcard(pattern: []const u8, dry_run: bool) !void {
    if (dry_run) {
        logger.info("[dry-run] List: {s}\n", .{pattern});
        return;
    }

    const io = currentIo();
    var base_dir = openBaseDirOrReport(dry_run) orelse return;
    defer base_dir.close(io);

    var matches = collectWildcardMatchesInDir(std.heap.page_allocator, base_dir.dir, io, pattern) catch |err| {
        switch (err) {
            error.PathNotFound => logger.err("Path not found: {s}\n", .{pattern}),
            else => logger.err("Failed to resolve wildcard pattern {s}: {s}\n", .{ pattern, @errorName(err) }),
        }
        return;
    };
    defer freeWildcardMatches(std.heap.page_allocator, &matches);

    var lines: std.ArrayList([]const u8) = .empty;
    defer freeOwnedLines(std.heap.page_allocator, &lines);

    for (matches.items) |match| {
        try lines.append(std.heap.page_allocator, try formatListEntry(
            std.heap.page_allocator,
            match.display_path,
            match.kind == .directory,
        ));
    }

    if (lines.items.len == 0) {
        logger.info("No files matched: {s}\n", .{pattern});
        return;
    }

    writeStdoutLines(lines.items);
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
        logger.info("[dry-run] List: {s}\n", .{path});
        return;
    }

    const io = currentIo();
    var base_dir = openBaseDirOrReport(dry_run) orelse return;
    defer base_dir.close(io);
    var dir = base_dir.dir.openDir(io, path, .{ .iterate = true }) catch {
        logger.err("Path not found: {s}\n", .{path});
        return;
    };
    defer dir.close(io);

    var lines = try collectListLines(std.heap.page_allocator, dir, io, null);
    defer freeOwnedLines(std.heap.page_allocator, &lines);

    writeStdoutLines(lines.items);
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
        logger.info("[dry-run] Exists check: {s}\n", .{path});
        return;
    }

    const io = currentIo();
    var base_dir = openBaseDirOrReport(dry_run) orelse return;
    defer base_dir.close(io);

    if (!pathExistsInDir(base_dir.dir, io, path)) {
        logger.info("{s} not found\n", .{path});
        return;
    }
    logger.info("{s} exists\n", .{path});
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
        logger.info("[dry-run] Read: {s}\n", .{path});
        return;
    }

    const io = currentIo();
    var base_dir = openBaseDirOrReport(dry_run) orelse return;
    defer base_dir.close(io);
    const content = readFileAllocInDir(base_dir.dir, io, std.heap.page_allocator, path) catch {
        logger.err("File not found: {s}\n", .{path});
        return;
    };
    defer std.heap.page_allocator.free(content);
    writeStdoutBytes(renderReadOutput(content));
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
    const io = currentIo();
    var base_dir = openBaseDirOrReport(dry_run) orelse return;
    defer base_dir.close(io);
    return fsWriteInDir(base_dir.dir, io, path, content, dry_run);
}

fn expectContainsLine(lines: []const []const u8, expected: []const u8) !void {
    for (lines) |line| {
        if (std.mem.eql(u8, line, expected)) return;
    }
    return error.TestExpectedEqual;
}

fn expectEqualBytes(expected: []const u8, actual: []const u8) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    try std.testing.expectEqualSlices(u8, expected, actual);
}

fn expectWildcardMatch(
    matches: []const WildcardMatch,
    expected_path: []const u8,
    expected_display_path: []const u8,
) !void {
    for (matches) |match| {
        if (std.mem.eql(u8, match.path, expected_path) and
            std.mem.eql(u8, match.display_path, expected_display_path))
        {
            return;
        }
    }
    return error.TestExpectedEqual;
}

fn setTestRuntime(environ_map: *std.process.Environ.Map) void {
    runtime.set(.{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .environ_map = environ_map,
    });
}

fn muteLogger() logger.LogLevel {
    const log = logger.getLogger();
    const old_level = log.level;
    log.level = .off;
    return old_level;
}

fn expectPathExists(dir: std.Io.Dir, path: []const u8) !void {
    try dir.access(std.testing.io, path, .{});
}

fn expectPathMissing(dir: std.Io.Dir, path: []const u8) !void {
    dir.access(std.testing.io, path, .{}) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    return error.TestUnexpectedResult;
}

const TestOutputCapture = struct {
    stdout: std.ArrayList(u8) = .empty,
    stderr: std.ArrayList(u8) = .empty,

    fn deinit(self: *TestOutputCapture, allocator: std.mem.Allocator) void {
        self.stdout.deinit(allocator);
        self.stderr.deinit(allocator);
    }

    fn stdoutSink(self: *TestOutputCapture) runtime.OutputSink {
        return .{
            .context = self,
            .writeFn = writeStdout,
        };
    }

    fn stderrSink(self: *TestOutputCapture) runtime.OutputSink {
        return .{
            .context = self,
            .writeFn = writeStderr,
        };
    }

    fn writeStdout(context: *anyopaque, bytes: []const u8) void {
        const self: *TestOutputCapture = @ptrCast(@alignCast(context));
        self.stdout.appendSlice(std.testing.allocator, bytes) catch unreachable;
    }

    fn writeStderr(context: *anyopaque, bytes: []const u8) void {
        const self: *TestOutputCapture = @ptrCast(@alignCast(context));
        self.stderr.appendSlice(std.testing.allocator, bytes) catch unreachable;
    }
};

const OutputSinkState = struct {
    stdout: ?runtime.OutputSink,
    stderr: ?runtime.OutputSink,
};

fn installOutputCapture(capture: *TestOutputCapture) OutputSinkState {
    return .{
        .stdout = runtime.swapOutputSink(.stdout, capture.stdoutSink()),
        .stderr = runtime.swapOutputSink(.stderr, capture.stderrSink()),
    };
}

fn restoreOutputCapture(state: OutputSinkState) void {
    _ = runtime.swapOutputSink(.stdout, state.stdout);
    _ = runtime.swapOutputSink(.stderr, state.stderr);
}

fn tmpDirPath(allocator: std.mem.Allocator, tmp: *std.testing.TmpDir) ![]u8 {
    return std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}", .{tmp.sub_path});
}

test "detectPathKindInDir distinguishes file directory and missing paths" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var docs_dir = try tmp.dir.createDirPathOpen(std.testing.io, "docs", .{});
    docs_dir.close(std.testing.io);
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "notes.txt",
        .data = "hello\n",
    });

    try std.testing.expectEqual(.file, detectPathKindInDir(tmp.dir, std.testing.io, "notes.txt"));
    try std.testing.expectEqual(.directory, detectPathKindInDir(tmp.dir, std.testing.io, "docs"));
    try std.testing.expectEqual(.missing, detectPathKindInDir(tmp.dir, std.testing.io, "missing.txt"));
}

test "destinationParentStatusInDir validates destination parents" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "artifact",
        .data = "marker\n",
    });
    var nested_dir = try tmp.dir.createDirPathOpen(std.testing.io, "build/output", .{});
    nested_dir.close(std.testing.io);

    try std.testing.expectEqual(.ready, destinationParentStatusInDir(tmp.dir, std.testing.io, "result.txt"));
    try std.testing.expectEqual(.ready, destinationParentStatusInDir(tmp.dir, std.testing.io, "build/output/app.txt"));
    try std.testing.expectEqual(.missing, destinationParentStatusInDir(tmp.dir, std.testing.io, "missing/app.txt"));
    try std.testing.expectEqual(.not_directory, destinationParentStatusInDir(tmp.dir, std.testing.io, "artifact/app.txt"));
}

test "matchesPathPattern supports recursive and segment wildcards" {
    try std.testing.expect(matchesPathPattern("app.zig", "*.zig"));
    try std.testing.expect(matchesPathPattern("nested/app.zig", "**/*.zig"));
    try std.testing.expect(matchesPathPattern("nested/deeper/app.zig", "**/*.zig"));
    try std.testing.expect(matchesPathPattern("packages/mobile/dist/app.js", "**/dist/*.js"));
    try std.testing.expect(matchesPathPattern("mobile/dist/app.js", "*/dist/*.js"));
    try std.testing.expect(!matchesPathPattern("packages/mobile/dist/app.js", "*/dist/*.js"));
    try std.testing.expect(matchesPathPattern("docs/guides/intro.md", "**/intro.md"));
    try std.testing.expect(!matchesPathPattern("docs/guides/intro.txt", "**/*.md"));
}

test "buildWildcardSearchPlan extracts fixed root and recursive suffix" {
    var plan = try buildWildcardSearchPlan(std.testing.allocator, "src/**/*.zig");
    defer plan.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("src", plan.root_path);
    try std.testing.expectEqualStrings("**/*.zig", plan.relative_pattern);
    try std.testing.expect(plan.recursive);

    var top_level = try buildWildcardSearchPlan(std.testing.allocator, "*.zig");
    defer top_level.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(".", top_level.root_path);
    try std.testing.expectEqualStrings("*.zig", top_level.relative_pattern);
    try std.testing.expect(!top_level.recursive);
}

test "collectWildcardMatchesInDir supports recursive patterns" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var nested_dir = try tmp.dir.createDirPathOpen(std.testing.io, "src/features/mobile", .{});
    nested_dir.close(std.testing.io);
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/app.zig",
        .data = "const app = 1;\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/features/mobile/page.zig",
        .data = "const page = 1;\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/features/mobile/page.txt",
        .data = "plain text\n",
    });

    var matches = try collectWildcardMatchesInDir(std.testing.allocator, tmp.dir, std.testing.io, "src/**/*.zig");
    defer freeWildcardMatches(std.testing.allocator, &matches);

    try std.testing.expectEqual(@as(usize, 2), matches.items.len);
    try expectWildcardMatch(matches.items, "src/app.zig", "app.zig");
    try expectWildcardMatch(matches.items, "src/features/mobile/page.zig", "features/mobile/page.zig");
}

test "collectWildcardMatchesInDir keeps immediate wildcard behavior for fixed directories" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var src_dir = try tmp.dir.createDirPathOpen(std.testing.io, "src", .{});
    src_dir.close(std.testing.io);
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/app.zig",
        .data = "const app = 1;\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/page.txt",
        .data = "plain text\n",
    });

    var matches = try collectWildcardMatchesInDir(std.testing.allocator, tmp.dir, std.testing.io, "src/*.zig");
    defer freeWildcardMatches(std.testing.allocator, &matches);

    try std.testing.expectEqual(@as(usize, 1), matches.items.len);
    try std.testing.expectEqualStrings("src/app.zig", matches.items[0].path);
    try std.testing.expectEqualStrings("app.zig", matches.items[0].display_path);
}

test "classifyMoveFailureInDir distinguishes source and destination errors" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var workspace_dir = try tmp.dir.createDirPathOpen(std.testing.io, "workspace/srcdir", .{});
    workspace_dir.close(std.testing.io);
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "workspace/source.txt",
        .data = "hello\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "workspace/dest.txt",
        .data = "existing\n",
    });
    var target_dir = try tmp.dir.createDirPathOpen(std.testing.io, "workspace/target", .{});
    target_dir.close(std.testing.io);

    try std.testing.expectEqual(
        MoveFailure.source_missing,
        classifyMoveFailureInDir(tmp.dir, std.testing.io, "workspace/missing.txt", "workspace/out.txt", error.FileNotFound),
    );
    try std.testing.expectEqual(
        MoveFailure.destination_parent_missing,
        classifyMoveFailureInDir(tmp.dir, std.testing.io, "workspace/source.txt", "workspace/missing/out.txt", error.FileNotFound),
    );
    try std.testing.expectEqual(
        MoveFailure.destination_existing_directory,
        classifyMoveFailureInDir(tmp.dir, std.testing.io, "workspace/source.txt", "workspace/target", error.IsDir),
    );
    try std.testing.expectEqual(
        MoveFailure.destination_existing_file,
        classifyMoveFailureInDir(tmp.dir, std.testing.io, "workspace/srcdir", "workspace/dest.txt", error.NotDir),
    );
}

test "collectListLines marks directories for listing output" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "alpha.txt",
        .data = "alpha\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "zeta.txt",
        .data = "zeta\n",
    });
    var docs_dir = try tmp.dir.createDirPathOpen(std.testing.io, "docs", .{});
    docs_dir.close(std.testing.io);

    var lines = try collectListLines(std.testing.allocator, tmp.dir, std.testing.io, null);
    defer freeOwnedLines(std.testing.allocator, &lines);

    try std.testing.expectEqual(@as(usize, 3), lines.items.len);
    try expectContainsLine(lines.items, "alpha.txt");
    try expectContainsLine(lines.items, "docs/");
    try expectContainsLine(lines.items, "zeta.txt");
}

test "collectListLines filters wildcard matches" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "app.zig",
        .data = "const app = 1;\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "README.md",
        .data = "# readme\n",
    });
    var src_dir = try tmp.dir.createDirPathOpen(std.testing.io, "src", .{});
    src_dir.close(std.testing.io);

    var lines = try collectListLines(std.testing.allocator, tmp.dir, std.testing.io, "*.zig");
    defer freeOwnedLines(std.testing.allocator, &lines);

    try std.testing.expectEqual(@as(usize, 1), lines.items.len);
    try std.testing.expectEqualStrings("app.zig", lines.items[0]);
}

test "renderListOutput formats indented lines with trailing newline" {
    const rendered = try renderListOutput(
        std.testing.allocator,
        &.{ "alpha.txt", "docs/" },
    );
    defer std.testing.allocator.free(rendered);

    try expectEqualBytes("  alpha.txt\n  docs/\n", rendered);
}

test "renderListOutput returns empty output for empty input" {
    const rendered = try renderListOutput(std.testing.allocator, &.{});
    defer std.testing.allocator.free(rendered);

    try expectEqualBytes("", rendered);
}

test "renderReadOutput preserves bytes exactly" {
    const raw = "line one\nline two";
    const rendered = renderReadOutput(raw);

    try expectEqualBytes(raw, rendered);
}

test "fsListWildcard dry run does not require an existing directory" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);

    const log = logger.getLogger();
    const old_level = log.level;
    const old_ansi = log.enable_ansi;
    defer {
        logger.getLogger().level = old_level;
        logger.getLogger().enable_ansi = old_ansi;
    }
    log.level = .info;
    log.enable_ansi = false;

    var capture = TestOutputCapture{};
    defer capture.deinit(std.testing.allocator);
    const previous_output = installOutputCapture(&capture);
    defer restoreOutputCapture(previous_output);

    try fsListWildcard("missing/*.zig", true);

    try std.testing.expectEqualStrings("[INFO]\n    [dry-run] List: missing/*.zig\n", capture.stdout.items);
    try std.testing.expectEqual(@as(usize, 0), capture.stderr.items.len);
}

test "fsListWildcard writes recursive matches to captured stdout" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);
    const old_level = muteLogger();
    const log = logger.getLogger();
    const old_ansi = log.enable_ansi;
    defer {
        logger.getLogger().level = old_level;
        logger.getLogger().enable_ansi = old_ansi;
    }
    log.enable_ansi = false;

    var capture = TestOutputCapture{};
    defer capture.deinit(std.testing.allocator);
    const previous_output = installOutputCapture(&capture);
    defer restoreOutputCapture(previous_output);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var src_dir = try tmp.dir.createDirPathOpen(std.testing.io, "src", .{});
    src_dir.close(std.testing.io);
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/app.zig",
        .data = "const app = 1;\n",
    });

    const dir_path = try tmpDirPath(std.testing.allocator, &tmp);
    defer std.testing.allocator.free(dir_path);

    const previous_cwd = runtime.swapFsCwd(dir_path);
    defer _ = runtime.swapFsCwd(previous_cwd);

    try fsListWildcard("src/**/*.zig", false);

    try std.testing.expectEqualStrings("  app.zig\n", capture.stdout.items);
    try std.testing.expectEqual(@as(usize, 0), capture.stderr.items.len);
}

test "fsRead writes file contents to captured stdout" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var capture = TestOutputCapture{};
    defer capture.deinit(std.testing.allocator);
    const previous_output = installOutputCapture(&capture);
    defer restoreOutputCapture(previous_output);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "notes.txt",
        .data = "hello world\n",
    });

    const dir_path = try tmpDirPath(std.testing.allocator, &tmp);
    defer std.testing.allocator.free(dir_path);

    const previous_cwd = runtime.swapFsCwd(dir_path);
    defer _ = runtime.swapFsCwd(previous_cwd);

    try fsRead("notes.txt", false);

    try std.testing.expectEqualStrings("hello world\n", capture.stdout.items);
    try std.testing.expectEqual(@as(usize, 0), capture.stderr.items.len);
}

test "fsMove reports missing source through captured stderr" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);

    const log = logger.getLogger();
    const old_level = log.level;
    const old_ansi = log.enable_ansi;
    defer {
        logger.getLogger().level = old_level;
        logger.getLogger().enable_ansi = old_ansi;
    }
    log.level = .info;
    log.enable_ansi = false;

    var capture = TestOutputCapture{};
    defer capture.deinit(std.testing.allocator);
    const previous_output = installOutputCapture(&capture);
    defer restoreOutputCapture(previous_output);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const dir_path = try tmpDirPath(std.testing.allocator, &tmp);
    defer std.testing.allocator.free(dir_path);

    const previous_cwd = runtime.swapFsCwd(dir_path);
    defer _ = runtime.swapFsCwd(previous_cwd);

    try fsMove("missing.txt", "out.txt", false);

    try std.testing.expectEqualStrings("[ERROR]\n    Source not found: missing.txt\n", capture.stderr.items);
    try std.testing.expectEqual(@as(usize, 0), capture.stdout.items.len);
}

test "fsRemoveWildcard removes nested matches when using recursive patterns" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var build_dir = try tmp.dir.createDirPathOpen(std.testing.io, "build/mobile/cache", .{});
    build_dir.close(std.testing.io);
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "build/mobile/cache/app.tmp",
        .data = "tmp\n",
    });
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "build/mobile/cache/keep.txt",
        .data = "keep\n",
    });

    const dir_path = try tmpDirPath(std.testing.allocator, &tmp);
    defer std.testing.allocator.free(dir_path);

    const previous_cwd = runtime.swapFsCwd(dir_path);
    defer _ = runtime.swapFsCwd(previous_cwd);

    try fsRemoveWildcard("build/**/*.tmp", false, false);

    try expectPathMissing(tmp.dir, "build/mobile/cache/app.tmp");
    try expectPathExists(tmp.dir, "build/mobile/cache/keep.txt");
}

test "fsCreateExtended respects runtime fs cwd override" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const dir_path = try tmpDirPath(std.testing.allocator, &tmp);
    defer std.testing.allocator.free(dir_path);

    const previous_cwd = runtime.swapFsCwd(dir_path);
    defer _ = runtime.swapFsCwd(previous_cwd);

    try fsCreateExtended("notes/daily.txt", false, true, false);

    try expectPathExists(tmp.dir, "notes/daily.txt");
}

test "fsCreateExtendedInDir creates nested file when recursive" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try fsCreateExtendedInDir(tmp.dir, std.testing.io, "notes/daily.txt", false, true, false);

    try expectPathExists(tmp.dir, "notes/daily.txt");
}

test "fsCreateExtendedInDir does not create nested file when recursive is false" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try fsCreateExtendedInDir(tmp.dir, std.testing.io, "notes/daily.txt", false, false, false);

    try expectPathMissing(tmp.dir, "notes/daily.txt");
}

test "fsCopyExtendedInDir copies nested directory contents" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var src_nested_dir = try tmp.dir.createDirPathOpen(std.testing.io, "src/nested", .{});
    src_nested_dir.close(std.testing.io);
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/nested/data.txt",
        .data = "payload\n",
    });

    try fsCopyExtendedInDir(tmp.dir, std.testing.io, "src", "backup", true, false);

    try expectPathExists(tmp.dir, "backup/nested/data.txt");
    const copied = try tmp.dir.readFileAlloc(
        std.testing.io,
        "backup/nested/data.txt",
        std.testing.allocator,
        .limited(64),
    );
    defer std.testing.allocator.free(copied);

    try std.testing.expectEqualStrings("payload\n", copied);
}

test "fsCopyExtendedInDir does not copy directory without recursive flag" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var src_nested_dir = try tmp.dir.createDirPathOpen(std.testing.io, "src/nested", .{});
    src_nested_dir.close(std.testing.io);
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/nested/data.txt",
        .data = "payload\n",
    });

    try fsCopyExtendedInDir(tmp.dir, std.testing.io, "src", "backup", false, false);

    try expectPathMissing(tmp.dir, "backup");
}

test "copyDirAllInDir surfaces nested destination conflicts" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var src_nested_dir = try tmp.dir.createDirPathOpen(std.testing.io, "src/nested", .{});
    src_nested_dir.close(std.testing.io);
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "src/nested/data.txt",
        .data = "payload\n",
    });

    var backup_dir = try tmp.dir.createDirPathOpen(std.testing.io, "backup", .{});
    backup_dir.close(std.testing.io);
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "backup/nested",
        .data = "conflict\n",
    });

    copyDirAllInDir(tmp.dir, std.testing.io, "src", "backup") catch |err| {
        const err_name = @errorName(err);
        try std.testing.expect(
            std.mem.eql(u8, err_name, "PathAlreadyExists") or
                std.mem.eql(u8, err_name, "NotDir"),
        );
        try expectPathMissing(tmp.dir, "backup/nested/data.txt");
        return;
    };

    return error.TestUnexpectedResult;
}

test "fsRemoveInDir removes recursive directory trees" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var cache_dir = try tmp.dir.createDirPathOpen(std.testing.io, "workspace/cache", .{});
    cache_dir.close(std.testing.io);
    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "workspace/cache/tmp.txt",
        .data = "trash\n",
    });

    try fsRemoveInDir(tmp.dir, std.testing.io, "workspace", true, false);

    try expectPathMissing(tmp.dir, "workspace");
}

test "fsMoveInDir renames files within the same directory" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "draft.txt",
        .data = "hello\n",
    });

    try fsMoveInDir(tmp.dir, std.testing.io, "draft.txt", "final.txt", false);

    try expectPathExists(tmp.dir, "final.txt");
    try expectPathMissing(tmp.dir, "draft.txt");
}

test "fsWriteInDir writes and overwrites file contents" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try fsWriteInDir(tmp.dir, std.testing.io, "state.txt", "draft\n", false);
    try fsWriteInDir(tmp.dir, std.testing.io, "state.txt", "final\n", false);

    const content = try tmp.dir.readFileAlloc(
        std.testing.io,
        "state.txt",
        std.testing.allocator,
        .limited(64),
    );
    defer std.testing.allocator.free(content);

    try std.testing.expectEqualStrings("final\n", content);
}

test "readFileAllocInDir returns file contents" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "notes.txt",
        .data = "hello world\n",
    });

    const content = try readFileAllocInDir(tmp.dir, std.testing.io, std.testing.allocator, "notes.txt");
    defer std.testing.allocator.free(content);

    try std.testing.expectEqualStrings("hello world\n", content);
}

test "pathExistsInDir reports existing and missing paths" {
    var environ_map = std.process.Environ.Map.init(std.testing.allocator);
    defer environ_map.deinit();
    setTestRuntime(&environ_map);
    const old_level = muteLogger();
    defer logger.getLogger().level = old_level;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.writeFile(std.testing.io, .{
        .sub_path = "present.txt",
        .data = "ok\n",
    });

    try std.testing.expect(pathExistsInDir(tmp.dir, std.testing.io, "present.txt"));
    try std.testing.expect(!pathExistsInDir(tmp.dir, std.testing.io, "missing.txt"));
}
