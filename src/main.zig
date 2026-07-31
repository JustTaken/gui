const std = @import("std");
const wayland = @import("wayland");
const vulkan = @import("vulkan");
const Allocator = @import("util").Allocator;

const Wayland = wayland.Wayland(Context);
const Vulkan = vulkan.Vulkan;

const Context = struct {
	wayland: Wayland,
	vulkan: Vulkan,
};

pub fn main() !void {
	var gpa = std.heap.GeneralPurposeAllocator(.{}){};
	defer _ = gpa.deinit();

	const gpa_allocator = gpa.allocator();

	const allocator = try Allocator.init(20, 20, gpa_allocator);
	defer allocator.deinit(gpa_allocator);

	const width: u32 = 400;
	const height: u32 = 400;

	_ = try allocator.main.create(Context);
	_ = try Vulkan.init(allocator, width, height);
	_ = try Wayland.init(allocator, width, height);
}

