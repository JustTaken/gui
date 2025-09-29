const std = @import("std");

pub fn build(builder: *std.Build) void {
    const target = builder.standardTargetOptions(.{});
    const optimize = builder.standardOptimizeOption(.{});

    const util_module = builder.addModule("Util", .{
        .root_source_file = builder.path("Util/Lib.zig"),
        .target = target,
    });

    const vulkan_module = builder.addModule("Vulkan", .{
        .root_source_file = builder.path("Vulkan/Lib.zig"),
        .target = target,
        .imports = &.{
            .{
                .name = "Util",
                .module = util_module,
            },
        },
    });

    const wayland_module = builder.addModule("Wayland", .{
        .root_source_file = builder.path("Wayland/Lib.zig"),
        .target = target,
        .imports = &.{
            .{
                .name = "Util",
                .module = util_module,
            },
        },
    });

    util_module.addIncludePath(builder.path("Asset/Include/"));
    wayland_module.linkSystemLibrary("wayland-client", .{});
    wayland_module.addCSourceFile(.{ .file = builder.path("Asset/Include/XdgShell.c") });

    const exe = builder.addExecutable(.{
        .name = "Gui",
        .root_module = builder.createModule(.{
            .root_source_file = builder.path("Source/Main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{
                    .name = "Vulkan",
                    .module = vulkan_module,
                },
                .{
                    .name = "Wayland",
                    .module = wayland_module,
                },
                .{
                    .name = "Util",
                    .module = util_module,
                },
            },
        }),
    });

    builder.installArtifact(exe);
    exe.linkLibC();

    const run_step = builder.step("run", "Run the app");
    const run_cmd = builder.addRunArtifact(exe);

    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(builder.getInstallStep());

    if (builder.args) |args| {
        run_cmd.addArgs(args);
    }

    // const mod_tests = builder.addTest(.{
    //     .root_module = vulkan_module,
    // });

    // const run_mod_tests = builder.addRunArtifact(mod_tests);
    // const exe_tests = builder.addTest(.{
    //     .root_module = exe.root_module,
    // });

    // const run_exe_tests = builder.addRunArtifact(exe_tests);
    // const test_step = builder.step("test", "Run tests");

    // test_step.dependOn(&run_mod_tests.step);
    // test_step.dependOn(&run_exe_tests.step);
}
