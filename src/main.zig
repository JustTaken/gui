const std = @import("std");
const wayland = @import("wayland");
const Allocator = @import("util").Allocator;

const Protocol = wayland.Protocol(Context);

const Context = struct {
	protocol: Protocol,
};

pub fn main() !void {
	var gpa = std.heap.GeneralPurposeAllocator(.{}){};
	defer _ = gpa.deinit();

	const gpa_allocator = gpa.allocator();

	const allocator = try Allocator.init(10, 10, gpa_allocator);
	defer allocator.deinit(gpa_allocator);

	const context = try allocator.main.create(Context);
	try Protocol.init(allocator, context);
}

