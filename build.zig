const std = @import("std");

pub fn build(builder: *std.Build) void {
	const target = builder.standardTargetOptions(.{});
	const optimize = builder.standardOptimizeOption(.{});

	const util_module = builder.addModule("util", .{
		.root_source_file = builder.path("util/root.zig"),
		.target = target,
		.optimize = optimize,
		.link_libc = true,
	});

	const xml_module = builder.addModule("xml", .{
		.root_source_file = builder.path("xml/root.zig"),
		.target = target,
		.optimize = optimize,
		.imports = &.{
			.{ .name = "util", .module = util_module },
		},
	});

	const wayland_generator_module = builder.addModule("wayland_generator", .{
		.root_source_file = builder.path("wayland/generator.zig"),
		.target = target,
		.optimize = optimize,
		.imports = &.{
			.{ .name = "xml", .module = xml_module },
		},
	});

	const wayland_module = builder.addModule("wayland", .{
		.root_source_file = builder.path("wayland/root.zig"),
		.target = target,
		.optimize = optimize,
		.link_libc = true,
		.imports = &.{
			.{ .name = "xml", .module = xml_module },
			.{ .name = "util", .module = util_module },
		},
	});

	const vulkan_module = builder.addModule("vulkan", .{
		.root_source_file = builder.path("vulkan/root.zig"),
		.target = target,
		.optimize = optimize,
		.link_libc = true,
		.imports = &.{
			.{ .name = "util", .module = util_module },
		},
	});

	const module = builder.addModule("exe", .{
		.root_source_file = builder.path("src/main.zig"),
		.target = target,
		.optimize = optimize,
		.link_libc = true,
		.imports = &.{
			.{ .name = "util", .module = util_module },
			.{ .name = "wayland", .module = wayland_module },
			.{ .name = "vulkan", .module = vulkan_module },
		},
	});

	const wayland_generator_exe = builder.addExecutable(.{
		.name = "wayland_generator",
		.root_module = wayland_generator_module,
	});

	const wayland_generator_step = builder.step("make", "Build wayland protocol from xml");
	const run_wayland_generator = builder.addRunArtifact(wayland_generator_exe);

	wayland_generator_step.dependOn(&run_wayland_generator.step);
	run_wayland_generator.step.dependOn(builder.getInstallStep());

	const exe = builder.addExecutable(.{
		.name = "exe",
		.root_module = module,
	});

	const run_step = builder.step("run", "Run the app");
	const run_cmd = builder.addRunArtifact(exe);

	run_step.dependOn(&run_cmd.step);
	run_cmd.step.dependOn(builder.getInstallStep());

	if (builder.args) |args| {
		run_cmd.addArgs(args);
	}
}

//    const util_module = builder.addModule("Util", .{
//        .root_source_file = builder.path("Util/Lib.zig"),
//        .target = target,
//    });
//
//    const json_parser_module = builder.addModule("JsonParser", .{
//        .root_source_file = builder.path("JsonParser/Lib.zig"),
//        .target = target,
//    });
//
//    const gltf_parser_module = builder.addModule("GltfParser", .{
//        .root_source_file = builder.path("GltfParser/Lib.zig"),
//        .target = target,
//        .imports = &.{
//            .{
//                .name = "JsonParser",
//                .module = json_parser_module,
//            },
//            .{
//                .name = "Util",
//                .module = util_module,
//            },
//        },
//    });
//
//    const vulkan_module = builder.addModule("Vulkan", .{
//        .root_source_file = builder.path("Vulkan/Lib.zig"),
//        .target = target,
//        .imports = &.{
//            .{
//                .name = "Util",
//                .module = util_module,
//            },
//        },
//    });
//
//    const wayland_module = builder.addModule("Wayland", .{
//        .root_source_file = builder.path("Wayland/Lib.zig"),
//        .target = target,
//        .imports = &.{
//            .{
//                .name = "Util",
//                .module = util_module,
//            },
//        },
//    });
//
//    util_module.addIncludePath(builder.path("Asset/Include/"));
//    wayland_module.linkSystemLibrary("wayland-client", .{});
//    wayland_module.linkSystemLibrary("xkbcommon", .{});
//    wayland_module.addCSourceFile(.{ .file = builder.path("Asset/Include/XdgShell.c") });
//
//    const exe = builder.addExecutable(.{
//        .name = "Gui",
//        .root_module = builder.createModule(.{
//            .root_source_file = builder.path("Source/Main.zig"),
//            .target = target,
//            .optimize = optimize,
//            .imports = &.{
//                .{
//                    .name = "Vulkan",
//                    .module = vulkan_module,
//                },
//                .{
//                    .name = "Wayland",
//                    .module = wayland_module,
//                },
//                .{
//                    .name = "GltfParser",
//                    .module = gltf_parser_module,
//                },
//                .{
//                    .name = "Util",
//                    .module = util_module,
//                },
//            },
//        }),
//    });
//
//    builder.installArtifact(exe);
//    exe.linkLibC();
//
//    const run_step = builder.step("run", "Run the app");
//    const run_cmd = builder.addRunArtifact(exe);
//
//    run_step.dependOn(&run_cmd.step);
//    run_cmd.step.dependOn(builder.getInstallStep());
//
//    if (builder.args) |args| {
//        run_cmd.addArgs(args);
//    }
//
//    const build_shaders = builder.option(bool, "shader", "Build shaders") orelse false;
//
//    if (build_shaders) {
//        compileShader(builder, "Asset/Shader", "FragmentShader.frag", "FragmentShader.spv");
//        compileShader(builder, "Asset/Shader", "VertexShader.vert", "VertexShader.spv");
//    }
//}
//
//fn compileShader(builder: *std.Build, base_dir: []const u8, input_path: []const u8, output_path: []const u8) void {
//    const shader_build = builder.addSystemCommand(&.{"glslc"});
//
//    const input_file_path = builder.path(builder.pathJoin(&.{ base_dir, input_path }));
//    shader_build.addFileArg(input_file_path);
//    shader_build.addArg("-o");
//
//    const out = shader_build.addOutputFileArg(output_path);
//    const file = builder.addInstallFileWithDir(out, .prefix, builder.pathJoin(&.{ base_dir, output_path }));
//
//    builder.getInstallStep().dependOn(&file.step);
//}
