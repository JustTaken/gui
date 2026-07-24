const std = @import("std");
const xml = @import("xml");

const Buffer = std.array_list.Managed(u8);

pub fn main() !void {
	var gpa = std.heap.GeneralPurposeAllocator(.{}){};
	const gpa_allocator = gpa.allocator();
	const gpa_bytes = try gpa_allocator.alloc(u8, 1024 * 1024);

	defer _ = gpa.deinit();
	defer gpa_allocator.free(gpa_bytes);

	var fixed_buffer = std.heap.FixedBufferAllocator.init(gpa_bytes);
	const fixed_allocator = fixed_buffer.allocator();

	const parser = try xml.Parser.parse(fixed_allocator, "asset/wayland_protocol/wayland.xml");
	var buffer = Buffer.init(fixed_allocator);
	try buffer.appendSlice(

	try buffer.appendSlice("const int = i32\n");
	try buffer.appendSlice("const uint = u32\n");
	try buffer.appendSlice("const fixed = i32\n");
	try buffer.appendSlice("const object = u32\n");
	try buffer.appendSlice("const new_id = u32\n");
	try buffer.appendSlice("const fd = i32\n");
	try buffer.appendSlice("const string = []u8\n"),
	try buffer.appendSlice("const array = []u8\n"),
	try buffer.appendSlice("inline fn insert_number(value: anytype, buffer: []u8) u32 {\n\tconst bytes = std.mem.asBytes(value);\n\tstd.mem.copyForwards(u8, buffer, bytes);\n\treturn bytes.len;\n}")
	try buffer.appendSlice("inline fn insert_int(value: int, buffer: []u8) u32 {\n\treturn insert_number(value, buffer);\n}")
	try buffer.appendSlice("inline fn insert_uint(value: uint, buffer: []u8) u32 {\n\treturn insert_number(value, buffer);\n}")
	try buffer.appendSlice("inline fn insert_fixed(value: fixed, buffer: []u8) u32 {\n\treturn insert_number(value, buffer);\n}")
	try buffer.appendSlice("inline fn insert_object(value: object, buffer: []u8) u32 {\n\treturn insert_number(value, buffer);\n}")
	try buffer.appendSlice("inline fn insert_new_id(value: new_id, buffer: []u8) u32 {\n\treturn insert_number(value, buffer);\n}")

	for (parser.nodes.items) |node| {
		if (std.mem.eql(u8, node.name, "protocol")) {
			for (node.childs.items) |child| {
				if (std.mem.eql(u8, child.name, "interface")) {
					try write_interface(child, &buffer, "wl_");
				} else {
					std.debug.print("not and interface: {s}\n", .{child.name});
				}
			}
		}
	}

	std.debug.print("{s}\n", .{buffer.items});
}

fn write_interface_function(node: xml.Parser.Node, buffer: *Buffer, prefix: []const u8, postfix: []const u8, interface_name: []const u8) !void {
	const function_name = node.properties.items[0].value;

	try buffer.appendSlice("\tfn ");
	try buffer.appendSlice(function_name);
	try buffer.appendSlice("_");
	try buffer.appendSlice(postfix);
	try buffer.appendSlice("(self: *");
	try buffer.appendSlice(interface_name[prefix.len..]);

	for (node.childs.items) |child| {
		if (std.mem.eql(u8, child.name, "arg")) {
			try buffer.appendSlice(", ");
			try buffer.appendSlice(child.properties.items[0].value);
			try buffer.appendSlice(": ");
			try buffer.appendSlice(child.properties.items[1].value);
		}
	}

	try buffer.appendSlice(") void {");
	try buffer.appendSlice("}\n");
}

fn write_interface(node: xml.Parser.Node, buffer: *Buffer, prefix: []const u8) !void {
	const interface_name = node.properties.items[0].value;
	const interface_version = node.properties.items[1].value;

	try buffer.appendSlice("const ");
	try buffer.appendSlice(interface_name[prefix.len..]);
	try buffer.appendSlice(" = struct {\n");

	for (node.childs.items) |child| {
		if (std.mem.eql(u8, child.name, "request")) {
			try write_interface_function(child, buffer, prefix, "request", interface_name);
		} else if (std.mem.eql(u8, child.name, "request")) {
			try write_interface_function(child, buffer, prefix, "event", interface_name);
		}
	}

	try buffer.appendSlice("\tconst name = ");
	try buffer.appendSlice(interface_name);

	try buffer.appendSlice(";\n\tconst version = ");
	try buffer.appendSlice(interface_version);
	try buffer.appendSlice(";\n");

	try buffer.appendSlice("};\n");
}

//const wl_display = struct {
//id: u32,
//
//const NAME = "wl_display";
//const VERSION = "1";
//
//fn sync_requets(self: *const display, callback: new_id, buffer: []u8) ![]u8 {
//}
//};
