const std = @import("std");
const Interface = @import("interface.zig");

const wl = Interface.Wl(Context);
const xdg = Interface.Xdg(Context);
const zwp = Interface.Zwp(Context);

const c = @cImport({
    @cInclude("sys/socket.h");
});

pub const Int = i32;
pub const Uint = u32;
pub const Fixed = i32;
pub const Object = u32;
pub const Fd = i32;
pub const String = []u8;
pub const Array = []u8;
pub const Opcode = u16;
pub const Id = Uint;
pub const NewId = Uint;
pub const MessageSize = u16;

pub const UnboundedNewId = struct {
	interface: String,
	version: Uint,
	id: Id,
};

const Context = struct {
	protocol: Protocol(Context),
};

pub fn main() !void {
	var gpa = std.heap.GeneralPurposeAllocator(.{}){};
	const gpa_allocator = gpa.allocator();
	const gpa_bytes = try gpa_allocator.alloc(u8, 1024 * 1024);

	defer _ = gpa.deinit();
	defer gpa_allocator.free(gpa_bytes);
	var fixed_buffer = std.heap.FixedBufferAllocator.init(gpa_bytes);
	const allocator = fixed_buffer.allocator();

	const context = try allocator.create(Context);
	try Protocol(Context).init(allocator, context);
}

pub fn Protocol(T: type) type {
	return struct {
		functions: std.ArrayList(Function),
		ptrs: std.ArrayList(*anyopaque),
		in_fds: std.ArrayList(Fd),
		out_fds: std.ArrayList(Fd),
		writer: Writer,
		reader: Reader,
		socket: std.posix.socket_t,
		allocator: std.mem.Allocator,

		const Function = *const fn (*anyopaque, *T, buffer: *Reader) void;

		const Self = @This();

		pub fn init(allocator: std.mem.Allocator, context: *T) !void {
			const env_map = try std.process.getEnvMap(allocator);

			const xdg_path = env_map.get("XDG_RUNTIME_DIR") orelse return error.EnvFailed;
			const wayland_display = env_map.get("WAYLAND_DISPLAY") orelse return error.DisplayFailed;

			const path = try std.fs.path.join(allocator, &.{xdg_path, wayland_display});

			const socket = try std.posix.socket(std.c.AF.UNIX, std.c.SOCK.STREAM, 0);
			defer std.posix.close(socket);

			var sockaddr = std.posix.sockaddr.un {
				.path = .{0} ** 108,
			};

			std.mem.copyForwards(u8, &sockaddr.path, path);
			sockaddr.path[path.len] = 0;

			try std.posix.connect(socket, @ptrCast(@alignCast(&sockaddr)), @sizeOf(std.posix.sockaddr.un));

			context.protocol = .{
				.functions = try std.ArrayList(Function).initCapacity(allocator, 50),
				.ptrs = try std.ArrayList(*anyopaque).initCapacity(allocator, 50),
				.in_fds = try std.ArrayList(Fd).initCapacity(allocator, 10),
				.out_fds = try std.ArrayList(Fd).initCapacity(allocator, 10),
				.writer = Writer.init(try allocator.alloc(u8, 4096)),
				.reader = Reader.init(try allocator.alloc(u8, 4096)),
				.socket = socket,
				.allocator = allocator,
			};

			const display = try context.protocol.alloc(wl.Display);

			display.error_callback = display_error;
			display.delete_id_callback = display_delete_id;

			const registry = try context.protocol.alloc(wl.Registry);

			registry.global_callback = registry_global;
			registry.global_remove_callback = registry_global_remove;

			display.get_registry_request(&context.protocol.writer, registry.id);

			try context.protocol.send_message();
			try context.protocol.read_message(context);
			try context.protocol.send_message();
		}

		pub fn alloc(self: *Self, K: type) !*K {
			const ptr = try self.allocator.create(K);
			ptr.id = @intCast(self.ptrs.items.len + 1);

			try self.functions.append(self.allocator, K.event);
			try self.ptrs.append(self.allocator, ptr);

			return ptr;
		}

		pub fn read_message(self: *Self, payload: *T) !void {
			var io = std.posix.iovec {
				.base = self.reader.data[self.reader.offset..].ptr,
				.len = @intCast(self.reader.data.len - self.reader.offset),
			};

			const fd_align = std.mem.alignForward(usize, @sizeOf(Fd) * self.in_fds.capacity / 2, @sizeOf(usize));
			const cmsg_align = std.mem.alignForward(usize, @sizeOf(cmsghdr), @sizeOf(usize));

			var header = Writer.init(try self.allocator.alloc(u8, cmsg_align + fd_align));
			const ioptr: *[1]std.posix.iovec = &io;

			var msg = std.posix.msghdr {
				.name = null,
				.namelen = 0,
				.iov = ioptr,
				.iovlen = 1,
				.control = header.data.ptr,
				.controllen = @intCast(header.data.len),
				.flags = 0,
			};

			const cmsg: *cmsghdr = @ptrCast(@alignCast(header.data.ptr));
			const msg_header_size = std.mem.alignForward(usize, @sizeOf(cmsghdr), @sizeOf(usize));
			const size = std.c.recvmsg(self.socket, &msg, 0);

			self.reader.size += @intCast(size);

			if (msg.controllen > 0) {
				const fd_count = (cmsg.len - msg_header_size) / @sizeOf(Fd);

				const fd_ptrs: [*]Fd = @ptrCast(@alignCast(header.data[msg_header_size..msg_header_size + @sizeOf(Fd) * fd_count].ptr));
				const fds = fd_ptrs[0..fd_count];

				try self.in_fds.appendSlice(self.allocator, fds);
			}

			while (try self.decode(payload)) {}
		}

		pub fn send_message(self: *Self) !void {
			if (self.writer.offset == 0) {
				return;
			}

			var io = std.posix.iovec {
				.base = self.writer.data.ptr,
				.len = @intCast(self.writer.offset),
			};

			const cmsg_align: usize = @intCast(std.mem.alignForward(usize, @sizeOf(cmsghdr), @sizeOf(usize)));
			const fd_size: usize = @intCast(self.out_fds.items.len * @sizeOf(Fd));

			var cmsg: cmsghdr = std.mem.zeroes(cmsghdr);
			cmsg.len = @intCast(cmsg_align + fd_size);
			cmsg.type = c.SCM_RIGHTS;
			cmsg.level = c.SOL_SOCKET;

			var header = Writer.init(try self.allocator.alloc(u8, 1024));
			header.write_raw(cmsghdr, cmsg);
			header.padd(cmsg_align - @sizeOf(cmsghdr));
			header.append(Fd, self.out_fds.items);

			const ioptr: *[1]std.posix.iovec = &io;
			const msg = std.posix.msghdr {
				.name = null,
				.namelen = 0,
				.iov = ioptr,
				.iovlen = 1,
				.control = header.data.ptr,
				.controllen = std.mem.alignForward(usize, header.offset, @sizeOf(usize)),
				.flags = 0,
			};

			if (try std.posix.sendmsg(self.socket, @ptrCast(@alignCast(&msg)), 0) != self.writer.offset) {
				return error.SendMessageFail;
			}

			self.writer.offset = 0;
			self.out_fds.clearRetainingCapacity();
		}

		fn decode(self: *Self, payload: *T) !bool {
			if (self.reader.size <= @sizeOf(usize) + self.reader.offset) return false;
			//std.debug.print("{any}\n", .{self.reader.data[0..self.reader.offset]});

			const obj = self.reader.read_object() - 1;

			if (self.ptrs.items.len <= obj) {
				return error.OutOfBounds;
			}

			self.functions.items[obj](self.ptrs.items[obj], payload, &self.reader);
			return true;
		}
	};
}
	
pub const Reader = struct {
	data: []u8,
	offset: usize,
	size: usize,

	pub fn init(data: []u8) Reader {
		 return .{
			.data = data,
			.offset = 0,
			.size = 0,
		};
	}

	pub fn read_raw(self: *Reader, T: type) T {
		const ptr = std.mem.bytesAsValue(T, self.data[self.offset..]);
		self.offset += @sizeOf(T);

		return ptr.*;
	}

	pub fn read_bytes(self: *Reader, count: usize) []u8 {
		const len = std.mem.alignForward(usize, count, @sizeOf(Uint));
		defer self.offset += len;
		return self.data[self.offset..self.offset + count - 1];
	}

	pub fn read_id(self: *Reader) Id {
		return self.read_raw(Id);
	}

	pub fn read_int(self: *Reader) Int {
		return self.read_raw(Int);
	}

	pub fn read_uint(self: *Reader) Uint {
		return self.read_raw(Uint);
	}

	pub fn read_fixed(self: *Reader) Fixed {
		return self.read_raw(Fixed);
	}

	pub fn read_object(self: *Reader) Object {
		return self.read_raw(Object);
	}

	pub fn read_message_size(self: *Reader) MessageSize {
		return self.read_raw(MessageSize);
	}

	pub fn read_opcode(self: *Reader) Opcode {
		return self.read_raw(Opcode);
	}

	pub fn read_string(self: *Reader) String {
		const count = self.read_uint();
		const bytes = self.read_bytes(count);

		return bytes;
	}

	pub fn read_array(self: *Reader) Array {
		const count = self.read_uint();
		const bytes = self.read_bytes(count);

		return bytes;
	}
};

pub const Writer = struct {
	data: []u8,
	offset: usize,

	pub fn init(data: []u8) Writer {
		return .{
			.data = data,
			.offset = 0,
		};
	}

	pub fn write_raw(self: *Writer, T: type, value: T) void {
		const bytes = std.mem.asBytes(&value);

		std.mem.copyForwards(u8, self.data[self.offset..], bytes);
		self.offset += bytes.len;
	}

	pub fn append(self: *Writer, T: type, items: []T) void {
		for (items) |item| {
			self.write_raw(T, item);
		}
	}

	pub fn reserve(self: *Writer, T: type) *T {
		defer self.offset += @sizeOf(T);
		return @ptrCast(@alignCast(self.data[self.offset..].ptr));
	}

	pub fn padd(self: *Writer, size: usize) void {
		@memset(self.data[self.offset..self.offset + size], 0);
		self.offset += size;
	}

	pub fn write_bytes(self: *Writer, bytes: []const u8, insert_null: bool) void {
		const total = std.mem.alignForward(usize, if (insert_null) bytes.len + 1 else bytes.len, @sizeOf(Uint));

		std.mem.copyForwards(u8, self.data[self.offset..], bytes);
		@memset(self.data[self.offset + bytes.len..self.offset + total], 0);

		self.offset += total;
	}

	pub fn write_int(self: *Writer, i: Int) void {
		self.write_raw(Int, i);
	}

	pub fn write_uint(self: *Writer, u: Uint) void {
		self.write_raw(Uint, u);
	}

	pub fn write_fixed(self: *Writer, f: Fixed) void {
		self.write_raw(Fixed, f);
	}

	pub fn write_object(self: *Writer, o: Object) void {
		self.write_raw(Object, o);
	}

	pub fn write_new_id(self: *Writer, i: NewId) void {
		self.write_raw(NewId, i);
	}

	pub fn write_opcode(self: *Writer, o: Opcode) void {
		self.write_raw(Opcode, o);
	}

	pub fn write_id(self: *Writer, i: Id) void {
		self.write_raw(Id, i);
	}

	pub fn write_string(self: *Writer, str: String) void {
		self.write_raw(Uint, @intCast(str.len));
		self.write_bytes(str, true);
	}

	pub fn write_array(self: *Writer, a: Array) void {
		self.write_raw(Uint, a.len, false);
		self.write_bytes(a);
	}

	pub fn reserve_message_size(self: *Writer) *MessageSize {
		return self.reserve(MessageSize);
	}

	pub fn write_unbounded_new_id(self: *Writer, i: UnboundedNewId) void {
		self.write_string(i.interface);
		self.write_raw(Uint, i.version);
		self.write_raw(Uint, i.id);
	}
};

fn display_error(context: *Context, display: *wl.Display, object: Object, code: Uint, message: String) void {
	std.debug.print("display_error\n", .{});
	_ = context;
	_ = display;
	_ = object;
	_ = code;
	_ = message;

	std.debug.print("An error has occured\n", .{});	
}

fn display_delete_id(context: *Context, display: *wl.Display, id: Uint) void {
	std.debug.print("display_delete_id\n", .{});
	_ = context;
	_ = display;
	_ = id;
}

fn registry_global(context: *Context, registry: *wl.Registry, name: Uint, interface: String, version: Uint) void {
	//std.debug.print("registry_global\n", .{});
	//std.debug.print("hello global: name: {d}, version: {d}, interface: {s} -> ", .{name, version, interface});

	// xdg_wm_base
	// wl_compositor
	// wl_seat
	// zwp_linux_dmabuf_v1

	if (std.mem.eql(u8, interface, xdg.WmBase.interface_name)) {
		const wm_base = context.protocol.alloc(xdg.WmBase) catch @panic("OUT OF MEMORY");
		wm_base.ping_callback = wm_base_ping;
		registry.bind_request(&context.protocol.writer, name, .{.interface = interface, .id = wm_base.id, .version = version});
	} else if (std.mem.eql(u8, interface, wl.Compositor.interface_name)) {
		const compositor = context.protocol.alloc(wl.Compositor) catch @panic("OUT OF MEMORY");
		registry.bind_request(&context.protocol.writer, name, .{.interface = interface, .id = compositor.id, .version = version});
	} else if (std.mem.eql(u8, interface, wl.Seat.interface_name)) {
		const seat = context.protocol.alloc(wl.Seat) catch @panic("OUT OF MEMORY");
		seat.capabilities_callback = seat_capabilities;
		seat.name_callback = seat_name;
		registry.bind_request(&context.protocol.writer, name, .{.interface = interface, .id = seat.id, .version = version});
	} else if (std.mem.eql(u8, interface, zwp.LinuxDmabufV1.interface_name)) {
		const dma = context.protocol.alloc(zwp.LinuxDmabufV1) catch @panic("OUT OF MEMORY");
		dma.format_callback = linux_dmabuf_v1_format;
		dma.modifier_callback = linux_dmabuf_v1_modifier;
		registry.bind_request(&context.protocol.writer, name, .{.interface = interface, .id = dma.id, .version = version});
	} else {
		std.debug.print("NOT BOUND\n", .{});
		return;
	}

	std.debug.print("BOUND\n", .{});
}

fn registry_global_remove(context: *Context, registry: *wl.Registry, name: Uint) void {
	std.debug.print("registry_global_remove\n", .{});
	_ = context;
	_ = registry;
	_ = name;
}

fn wm_base_ping(context: *Context, wm_base: *xdg.WmBase, serial: Uint) void {
	std.debug.print("wm_base_ping\n", .{});
	wm_base.pong_request(&context.protocol.writer, serial);
}

fn seat_capabilities(context: *Context, seat: *wl.Seat, capabilities: Uint) void {
	std.debug.print("seat_capabilities\n", .{});
	_ = context;
	_ = seat;
	_ = capabilities;
}

fn seat_name(context: *Context, seat: *wl.Seat, name: String) void {
	std.debug.print("seat_name\n", .{});
	_ = context;
	_ = seat;
	_ = name;
}

fn linux_dmabuf_v1_format(context: *Context, linux_dmabuf_v1: *zwp.LinuxDmabufV1, format: Uint) void {
	std.debug.print("linux_dmabuf_v1_format\n", .{});
	_ = context;
	_ = linux_dmabuf_v1;
	_ = format;
}

fn linux_dmabuf_v1_modifier(context: *Context, linux_dmabuf_v1: *zwp.LinuxDmabufV1, format: Uint, modifier_hi: Uint, modifier_lo: Uint) void {
	std.debug.print("linux_dmabuf_v1_modifier\n", .{});
	_ = context;
	_ = linux_dmabuf_v1;
	_ = format;
	_ = modifier_hi;
	_ = modifier_lo;
}

const cmsghdr = extern struct {
	len: usize,
	level: i32,
	type: i32,
};

// object, opcode, size, name, interface, version
// u32, u16, u16, u32, string, u32
