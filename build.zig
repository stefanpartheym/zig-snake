const std = @import("std");

pub fn build(b: *std.Build) void {
    const options = .{
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    };

    const exe = b.addExecutable(.{
        .name = "zig-snake",
        .root_source_file = b.path("src/main.zig"),
        .target = options.target,
        .optimize = options.optimize,
        .link_libc = true,
    });
    b.installArtifact(exe);

    // Dependencies
    const raylib_dep = b.dependency("raylib-zig", options);

    // Add dependencies to the executable.
    exe.root_module.addImport("raylib", raylib_dep.module("raylib"));
    // Link aginas raylib.
    exe.linkLibrary(raylib_dep.artifact("raylib"));

    // Declare executable tests.
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = options.target,
        .optimize = options.optimize,
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Run executable.
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the game");
    run_step.dependOn(&run_cmd.step);

    // Run tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
