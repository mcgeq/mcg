const builtin = @import("builtin");
const std = @import("std");

const manifest_contents = @embedFile("build.zig.zon");
const version_key = ".version = \"";

fn ensureRequiredZigVersion() void {
    const required = std.SemanticVersion.parse("0.16.0") catch unreachable;
    if (builtin.zig_version.order(required) != .eq) {
        std.debug.panic(
            "mg requires Zig {f} exactly; found Zig {f}. Use the version declared in build.zig.zon before building.",
            .{ required, builtin.zig_version },
        );
    }
}

fn getManifestVersion() []const u8 {
    const start = std.mem.indexOf(u8, manifest_contents, version_key) orelse
        @panic("build.zig.zon is missing .version");
    const value_start = start + version_key.len;
    const value_end = std.mem.indexOfScalarPos(u8, manifest_contents, value_start, '"') orelse
        @panic("build.zig.zon .version is missing a closing quote");
    return manifest_contents[value_start..value_end];
}

pub fn build(b: *std.Build) void {
    ensureRequiredZigVersion();

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const package_version = getManifestVersion();
    const exe_version = std.SemanticVersion.parse(package_version) catch
        @panic("build.zig.zon .version must be a valid semantic version");
    const build_options = b.addOptions();
    build_options.addOption([]const u8, "mg_version", package_version);
    const root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    root_module.addOptions("build_options", build_options);

    const exe = b.addExecutable(.{
        .name = "mg",
        .version = exe_version,
        .root_module = root_module,
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run mg");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_tests.step);

    if (b.args) |args| {
        run_exe_tests.addArgs(args);
    }

    const smoke_exe = b.addExecutable(.{
        .name = "mg-smoke",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/smoke.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const smoke_step = b.step("smoke", "Run smoke verification against locally available package managers");
    const run_smoke = b.addRunArtifact(smoke_exe);
    run_smoke.addArtifactArg(exe);
    run_smoke.setCwd(b.path("."));
    smoke_step.dependOn(&run_smoke.step);

    if (b.args) |args| {
        run_smoke.addArgs(args);
    }
}
