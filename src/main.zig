const std = @import("std");
const cli = @import("cli.zig");
const fs = @import("fs/mod.zig");
const pkgm = @import("pkgm/mod.zig");
const MgError = @import("error.zig").MgError;

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.heap.page_allocator.free(args);

    if (args.len < 2) {
        cli.printHelp();
        return;
    }

    const result = cli.parse(args);
    switch (result) {
        .help => cli.printHelp(),
        .fs => {},
        .pkg => {
            const action = args[2];
            const packages = args[3..];
            try pkgm.executeCommand(action, packages, false);
        },
        .none => {},
    }
}
