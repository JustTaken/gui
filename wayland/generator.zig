// Note for second version, make each callback field optional and panic when there is no implementation of this function
// Make enum as packed struct with boolean fields
// Make events a union struct so the caller can implement just one even callback function and swith on event kinds.

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
	const allocator = fixed_buffer.allocator();

	try generate(allocator);
}

pub fn capitalize(buffer: *Buffer, string: []const u8) !void {
	if (string.len == 0) return;

	var upper = true;

	for (string) |c| {
		if (c == '_') {
			upper = true;
			continue;
		}

		if (upper) {
			try buffer.append(std.ascii.toUpper(c));
			upper = false;
		} else {
			try buffer.append(c);
		}
	}
}

pub fn generate(allocator: std.mem.Allocator) !void {
	var buffer = Buffer.init(allocator);
	
	const protocols: []const [2][]const u8 = &.{
		.{"asset/wayland_protocol/wayland.xml", "wl_"},
		.{"asset/wayland_protocol/xdg_shell.xml", "xdg_"},
		.{"asset/wayland_protocol/linux_dmabuf_v1.xml", "zwp_"},
	};

	try buffer.appendSlice("const root = @import(\"root.zig\");\n");
	try buffer.appendSlice("const Int = root.Int;\n");
	try buffer.appendSlice("const Uint = root.Uint;\n");
	try buffer.appendSlice("const Fixed = root.Fixed;\n");
	try buffer.appendSlice("const Object = root.Object;\n");
	try buffer.appendSlice("const Fd = root.Fd;\n");
	try buffer.appendSlice("const String = root.String;\n");
	try buffer.appendSlice("const Array = root.Array;\n");
	try buffer.appendSlice("const NewId = root.NewId;\n");
	try buffer.appendSlice("const UnboundedNewId = root.UnboundedNewId;\n");
	try buffer.appendSlice("const Id = root.Id;\n");
	try buffer.appendSlice("const Writer = root.Writer;\n");
	try buffer.appendSlice("const Reader = root.Reader;\n");

	for (protocols) |protocol| {
		const path = protocol[0];
		const prefix = protocol[1];

		const parser = try xml.Parser.parse(allocator, path);

		try buffer.appendSlice("pub fn ");
		try capitalize(&buffer, prefix[0..prefix.len - 1]);
		try buffer.appendSlice("(T: type) type {\n");
		try buffer.appendSlice("\treturn struct {\n");

		for (parser.nodes.items) |node| {
			if (std.mem.eql(u8, node.name, "protocol")) {
				for (node.childs.items) |child| {
					if (std.mem.eql(u8, child.name, "interface")) {
						try write_interface(child, &buffer, prefix);
					}
				}
			}
		}

		try buffer.appendSlice("\t};\n}\n");
	}

	const output_file = try std.fs.cwd().createFile("wayland/interface.zig", .{.read = true});
	try output_file.writeAll(buffer.items);
}

fn write_interface_function_request(node: xml.Parser.Node, buffer: *Buffer, prefix: []const u8, interface_name: []const u8, opcode: usize) !void {
	const function_name = node.properties.items[0].value;
	const postfix = "request";

	try buffer.appendSlice("\t\t\tpub fn ");
	try buffer.appendSlice(function_name);
	try buffer.appendSlice("_");
	try buffer.appendSlice(postfix);
	try buffer.appendSlice("(self: *const ");

	try capitalize(buffer, interface_name[prefix.len..]);

	try buffer.appendSlice(", writer: *Writer");

	for (node.childs.items) |child| {
		if (std.mem.eql(u8, child.name, "arg")) {
			try buffer.appendSlice(", ");
			try buffer.appendSlice(child.properties.items[0].value);
			try buffer.appendSlice(": ");
			try capitalize(buffer, distinguish_ids(child));
		}
	}

	try buffer.appendSlice(") void {\n");

	try buffer.print("\t\t\t\tconst opcode = {d};\n", .{opcode});
	try buffer.appendSlice("\t\t\t\tconst off = writer.offset;\n");
	try buffer.appendSlice("\t\t\t\twriter.write_id(self.id);\n");
	try buffer.appendSlice("\t\t\t\twriter.write_opcode(opcode);\n");
	try buffer.appendSlice("\t\t\t\tconst message_size = writer.reserve_message_size();\n");

	for (node.childs.items) |child| {
		if (std.mem.eql(u8, child.name, "arg")) {
			try buffer.appendSlice("\t\t\t\twriter.write_");
			try buffer.appendSlice(distinguish_ids(child));
			try buffer.appendSlice("(");
			try buffer.appendSlice(child.properties.items[0].value);
			try buffer.appendSlice(");\n");
		}
	}

	try buffer.appendSlice("\t\t\t\tmessage_size.* = @intCast(writer.offset - off);\n");

	try buffer.appendSlice("\t\t\t}\n");
}

fn write_interface_function_event(node: xml.Parser.Node, buffer: *Buffer, prefix: []const u8, interface_name: []const u8) !void {
	const function_name = node.properties.items[0].value;
	const postfix = "event";

	try buffer.appendSlice("\t\t\tpub fn ");
	try buffer.appendSlice(function_name);
	try buffer.appendSlice("_");
	try buffer.appendSlice(postfix);
	try buffer.appendSlice("(self: *");
	try capitalize(buffer, interface_name[prefix.len..]);

	try buffer.appendSlice(", ptr: *T, reader: *Reader) void {\n");
	var has_body = false;

	for (node.childs.items) |child| {
		if (std.mem.eql(u8, child.name, "arg")) {
			try buffer.appendSlice("\t\t\t\tconst ");
			try buffer.appendSlice(child.properties.items[0].value);
			try buffer.appendSlice(" = reader.read_");
			try buffer.appendSlice(child.properties.items[1].value);
			try buffer.appendSlice("();\n");
			has_body = true;
		}
	}

	if (!has_body) {
		try buffer.appendSlice("\t\t\t_ = reader;\n");
	}

	try buffer.appendSlice("\t\t\t\tself.");
	try buffer.appendSlice(function_name);
	try buffer.appendSlice("_callback(ptr, self");

	for (node.childs.items) |child| {
		if (std.mem.eql(u8, child.name, "arg")) {
			try buffer.appendSlice(", ");
			try buffer.appendSlice(child.properties.items[0].value);
		}
	}

	try buffer.appendSlice(");\n");

	try buffer.appendSlice("\t\t\t}\n");
}

fn write_interface_event(node: xml.Parser.Node, buffer: *Buffer, prefix: []const u8, interface_name: []const u8) !void {
	const function_name = node.properties.items[0].value;

	try buffer.appendSlice("\t\t\t");
	try buffer.appendSlice(function_name);
	try buffer.appendSlice("_callback: *const fn(*T, *");
	try capitalize(buffer, interface_name[prefix.len..]);

	for (node.childs.items) |child| {
		if (std.mem.eql(u8, child.name, "arg")) {
			try buffer.appendSlice(", ");
			try capitalize(buffer, child.properties.items[1].value);
		}
	}

	try buffer.appendSlice(") void,\n");
}

fn write_interface_enum(node: xml.Parser.Node, buffer: *Buffer) !void {
	const enum_name = node.properties.items[0].value;

	try buffer.appendSlice("\t\t\tpub const ");
	try capitalize(buffer, enum_name);
	try buffer.appendSlice(" = enum(Uint) {\n");

	for (node.childs.items) |child| {
		if (std.mem.eql(u8, child.name, "entry")) {
			try buffer.appendSlice("\t\t\t\t@\"");
			try buffer.appendSlice(child.properties.items[0].value);
			try buffer.appendSlice("\" = ");
			try buffer.appendSlice(child.properties.items[1].value);
			try buffer.appendSlice(",\n");
		}
	}

	try buffer.appendSlice("\t\t\t};\n");
}

fn write_interface(node: xml.Parser.Node, buffer: *Buffer, prefix: []const u8) !void {
	const interface_name = node.properties.items[0].value;
	const interface_version = node.properties.items[1].value;

	try buffer.appendSlice("\t\tpub const ");
	try capitalize(buffer, interface_name[prefix.len..]);
	try buffer.appendSlice(" = struct {\n");
	try buffer.appendSlice("\t\t\tid: Id,\n");

	var requests: [20]usize = undefined;
	var request_size: usize = 0;

	var events: [20]usize = undefined;
	var event_size: usize = 0;

	var enums: [20]usize = undefined;
	var enum_size: usize = 0;

	for (node.childs.items, 0..) |child, i| {
		if (std.mem.eql(u8, child.name, "request")) {
			requests[request_size] = i;
			request_size += 1;
		} else if (std.mem.eql(u8, child.name, "event")) {
			events[event_size] = i;
			event_size += 1;
		} else if (std.mem.eql(u8, child.name, "enum")) {
			enums[enum_size] = i;
			enum_size += 1;
		}
	}

	for (events[0..event_size]) |i| {
			try write_interface_event(node.childs.items[i], buffer, prefix, interface_name);
	}

	try buffer.appendSlice("\t\t\tpub const interface_name = \"");
	try buffer.appendSlice(interface_name);

	try buffer.appendSlice("\";\n\t\t\tpub const interface_version = \"");
	try buffer.appendSlice(interface_version);
	try buffer.appendSlice("\";\n");

	try buffer.appendSlice("\t\t\tpub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {\n");
	try buffer.appendSlice("\t\t\t\tconst opcode = reader.read_opcode();\n");
	try buffer.appendSlice("\t\t\t\tconst size = reader.read_message_size();\n");
	try buffer.appendSlice("\t\t\t\t_ = size;\n");

	if (event_size == 0) {
		try buffer.appendSlice("\t\t\t\t_ = self_ptr;\n");
		try buffer.appendSlice("\t\t\t\t_ = ptr;\n");
	}

	try buffer.appendSlice("\t\t\t\tswitch (opcode) {\n");


	for (events[0..event_size], 0..) |i, e| {
		try buffer.print("\t\t\t\t\t{d} => ", .{e});
		try buffer.appendSlice(node.childs.items[i].properties.items[0].value);
		try buffer.appendSlice("_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),\n");
	}

	try buffer.appendSlice("\t\t\t\t\t else => @panic(\"Unknown opcode\"),\n");

	try buffer.appendSlice("\t\t\t\t}\n");
	try buffer.appendSlice("\t\t\t}\n");

	for (enums[0..enum_size]) |i| {
		try write_interface_enum(node.childs.items[i], buffer);
	}

	for (events[0..event_size]) |i| {
		try write_interface_function_event(node.childs.items[i], buffer, prefix, interface_name);
	}

	for (requests[0..request_size], 0..) |i, code| {
		try write_interface_function_request(node.childs.items[i], buffer, prefix, interface_name, code);
	}

	try buffer.appendSlice("\t\t};\n");
}

fn distinguish_ids(node: xml.Parser.Node) []const u8 {
	if (std.mem.eql(u8, node.properties.items[1].value, "new_id")) {
		const has_interface = node.properties.items.len >= 2 and std.mem.eql(u8, node.properties.items[2].name, "interface");

		if (!has_interface) {
			return "unbounded_new_id";
		}
	}

	return node.properties.items[1].value;
}
