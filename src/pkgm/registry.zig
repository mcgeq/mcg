const ManagerType = @import("../types.zig").ManagerType;

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

pub fn getCommand(manager_type: ManagerType, action: []const u8, packages: []const [:0]u8) ?[]const u8 {
    const cmd = action[0];
    switch (cmd) {
        'a', 'A' => {
            if (packages.len == 0) return null;
            return switch (manager_type) {
                .cargo => "add",
                .npm, .pnpm, .bun, .yarn => "install",
                .pip => "install",
                .poetry, .pdm => "add",
            };
        },
        'r', 'R' => {
            if (packages.len == 0) return null;
            return switch (manager_type) {
                .cargo => "remove",
                .npm => "uninstall",
                .pnpm, .bun, .yarn => "remove",
                .pip => "uninstall",
                .poetry, .pdm => "remove",
            };
        },
        'u', 'U' => return "update",
        'i', 'I' => return switch (manager_type) {
            .cargo => "check",
            else => "install",
        },
        'l', 'L' => return switch (manager_type) {
            .cargo => "tree",
            .npm, .pnpm, .bun, .yarn, .pip, .poetry, .pdm => "list",
        },
        else => return null,
    }
    return null;
}
