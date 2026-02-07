const std = @import("std");
const MgError = @import("error.zig").MgError;

pub const ManagerType = enum(u8) {
    cargo,
    npm,
    pnpm,
    bun,
    yarn,
    pip,
    poetry,
    pdm,
};

pub const PackageOptions = struct {
    args: std.ArrayList([]const u8),
    dev: bool = false,
    dry_run: bool = false,

    pub fn init(allocator: std.mem.Allocator) PackageOptions {
        return PackageOptions{
            .args = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *PackageOptions) void {
        self.args.deinit();
    }

    pub fn addArg(self: *PackageOptions, arg: []const u8) void {
        self.args.append(arg) catch {};
    }
};

pub const CommandArgs = struct {
    packages: std.ArrayList([]const u8),
    manager_args: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) CommandArgs {
        return CommandArgs{
            .packages = std.ArrayList([]const u8).init(allocator),
            .manager_args = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *CommandArgs) void {
        self.packages.deinit();
        self.manager_args.deinit();
    }
};

pub const PackageManager = struct {
    name: *const fn () []const u8,
    formatCommand: *const fn (command: []const u8, packages: [][]const u8, options: *PackageOptions) []const u8,
    execute: *const fn (command: []const u8, packages: [][]const u8, options: *PackageOptions) MgError!void,
};

pub fn getManagerName(manager_type: ManagerType) []const u8 {
    return switch (manager_type) {
        .cargo => "cargo",
        .npm => "npm",
        .pnpm => "pnpm",
        .bun => "bun",
        .yarn => "yarn",
        .pip => "pip",
        .poetry => "poetry",
        .pdm => "pdm",
    };
}

pub fn parseManagerType(name: []const u8) ?ManagerType {
    const lower = std.ascii.lowerString(name);
    if (std.mem.eql(u8, lower, "cargo")) return .cargo;
    if (std.mem.eql(u8, lower, "npm")) return .npm;
    if (std.mem.eql(u8, lower, "pnpm")) return .pnpm;
    if (std.mem.eql(u8, lower, "bun")) return .bun;
    if (std.mem.eql(u8, lower, "yarn")) return .yarn;
    if (std.mem.eql(u8, lower, "pip")) return .pip;
    if (std.mem.eql(u8, lower, "poetry")) return .poetry;
    if (std.mem.eql(u8, lower, "pdm")) return .pdm;
    return null;
}
