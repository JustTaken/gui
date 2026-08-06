const std = @import("std");
const wayland = @import("wayland");
//const vulkan = @import("vulkan");
const Allocator = @import("util").Allocator;

const Wayland = wayland.Wayland(Context);
//const Vulkan = vulkan.Vulkan;

const Context = struct {
	wayland: Wayland,
	//vulkan: Vulkan,
};

pub fn main(init: std.process.Init) !void {
	const allocator = try Allocator.init(init.arena.allocator(), 20, 20);

	const width: u32 = 400;
	const height: u32 = 400;

	_ = try allocator.main.create(Context);
	//_ = env;
	//_ = try Vulkan.init(allocator, width, height);
	_ = try Wayland.init(allocator, init.environ_map, width, height);
}

