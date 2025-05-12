const std = @import("std");

pub fn build(b: *std.Build) void {
    const logic_only = b.option(bool, "logic_only", "only build the logic code contained in the shared library") orelse false;

    const target = std.Build.standardTargetOptions(b, .{});
    const optimize = std.Build.standardOptimizeOption(b, .{});

    // defining dependencies and modules
    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
        .shared = true,
    });

    const raylib = raylib_dep.module("raylib");
    const raygui = raylib_dep.module("raygui");
    const raylib_artifact = raylib_dep.artifact("raylib");

    const logic_lib = b.addSharedLibrary(.{
        .name = "logic",
        .root_source_file = .{
            .src_path = .{
                .owner = b,
                .sub_path = "src/logic.zig",
            },
        },
        .target = target,
        .optimize = optimize,
    });

    logic_lib.linkLibrary(raylib_artifact);
    logic_lib.root_module.addImport("raylib", raylib);
    logic_lib.root_module.addImport("raygui", raygui);

    b.installArtifact(logic_lib);

    if (!logic_only) {
        const main_module = b.addModule("main", .{
            .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/main.zig" } },
            .target = target,
            .optimize = optimize,
        });

        const exe = b.addExecutable(.{
            .root_module = main_module,
            .name = "floating_point",
        });

        exe.linkLibrary(raylib_artifact);
        exe.root_module.addImport("raylib", raylib);
        exe.root_module.addImport("raygui", raygui);

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);

        run_cmd.step.dependOn(b.getInstallStep());

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);

        // the "check" step helps zls
        {
            // codegen only runs if zig build sees a dependency on the binary output of
            // the step. So we duplicate the build definition so that it doesn't get polluted by
            // b.installArtifact.
            const lib_check = b.addSharedLibrary(.{
                .name = "check",
                .root_source_file = b.path("src/logic.zig"),
                .target = target,
                .optimize = optimize,
            });

            lib_check.linkLibrary(raylib_artifact);
            lib_check.root_module.addImport("raylib", raylib);
            lib_check.root_module.addImport("raygui", raygui);

            const check = b.step("check", "Check if it compiles");
            check.dependOn(&lib_check.step);
        }
    }
}
