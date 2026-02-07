const fs = @import("../fs.zig");
pub const commands = @import("commands.zig");

pub fn handleCommand(cmd: []const u8, args: []const [:0]u8, dry_run: bool) !void {
    try commands.handleCommand(cmd, args, dry_run);
}
