const std = @import("std");

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
