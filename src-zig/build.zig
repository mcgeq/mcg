const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "mg",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);

    const run_step = b.addRunArtifact(exe);
    b.default_step.dependOn(&run_step.step);

    std.debug.print("\n=== mg executable ===\n", .{});
    std.debug.print("Path: F:\\mcgeq\\mcg\\src-zig\\zig-out\\bin\\mg.exe\n\n", .{});
    std.debug.print("To add to PATH, run:\n", .{});
    std.debug.print("  set PATH=F:\\mcgeq\\mcg\\src-zig\\zig-out\\bin;%PATH%\n\n", .{});
    std.debug.print("Or create alias:\n", .{});
    std.debug.print("  alias mg='F:\\mcgeq\\mcg\\src-zig\\zig-out\\bin\\mg.exe'\n", .{});
    std.debug.print("==================\n", .{});
}
