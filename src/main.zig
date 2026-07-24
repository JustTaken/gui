const std = @import("std");
const xml = @import("xml");

pub fn main() !void {
	var gpa = std.heap.GeneralPurposeAllocator(.{}){};
	const gpa_allocator = gpa.allocator();
	const gpa_bytes = try gpa_allocator.alloc(u8, 1024 * 1024);

	defer _ = gpa.deinit();
	defer gpa_allocator.free(gpa_bytes);

	var fixed_buffer = std.heap.FixedBufferAllocator.init(gpa_bytes);

	const parser = try xml.Parser.parse(fixed_buffer.allocator(), "asset/wayland_protocol/xdg_shell.xml");
	_ = parser;
}
