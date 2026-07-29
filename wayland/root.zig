const std = @import("std");
const Interface = @import("interface.zig");
const Allocator = @import("util").Allocator;

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

const cmsghdr = extern struct {
	len: usize,
	level: i32,
	type: i32,
};

pub fn Wayland(T: type) type {
	_ = T;

	return struct {
		functions: std.ArrayList(Function),
		ptrs: std.ArrayList(*anyopaque),
		writer: Writer,
		reader: Reader,
		socket: std.posix.socket_t,

		width: usize,
		height: usize,

		running: bool,

		drm_formats: []DrmFormat,

		wl_display: *wl.Display,
		wl_registry: *wl.Registry,
		wl_compositor: *wl.Compositor,
		wl_seat: *wl.Seat,
		wl_surface: *wl.Surface,

		xdg_wm_base: *xdg.WmBase,
		xdg_surface: *xdg.Surface,
		xdg_toplevel: *xdg.Toplevel,

		zwp_linux_dmabuf_v1: *zwp.LinuxDmabufV1,
		zwp_linux_dmabuf_feedback_v1: *zwp.LinuxDmabufFeedbackV1,
		zwp_linux_buffer_params_v1: *zwp.LinuxBufferParamsV1,

		wl_buffer: *Buffer,

		const Self = @This();

		const wl = Interface.Wl(Self);
		const xdg = Interface.Xdg(Self);
		const zwp = Interface.Zwp(Self);

		const Function = *const fn (*anyopaque, *Self, buffer: *Reader) void;

		const Buffer = struct {
			handle: wl.Buffer,
			released: bool,
		};

		const DrmFormat = struct {
			format: u32,
			modifier: u64,
		};

		pub fn init(allocator: *Allocator, width: usize, height: usize) !void {
			const env_map = try std.process.getEnvMap(allocator.tmp);

			const xdg_path = env_map.get("XDG_RUNTIME_DIR") orelse return error.EnvFailed;
			const wayland_display = env_map.get("WAYLAND_DISPLAY") orelse return error.DisplayFailed;

			const path = try std.fs.path.join(allocator.tmp, &.{xdg_path, wayland_display});

			const socket = try std.posix.socket(std.c.AF.UNIX, std.c.SOCK.STREAM, 0);
			defer std.posix.close(socket);

			var sockaddr = std.posix.sockaddr.un {
				.path = .{0} ** 108,
			};

			std.mem.copyForwards(u8, &sockaddr.path, path);
			sockaddr.path[path.len] = 0;

			try std.posix.connect(socket, @ptrCast(@alignCast(&sockaddr)), @sizeOf(std.posix.sockaddr.un));

			const wl_display = try allocator.main.create(wl.Display);
			const wl_registry = try allocator.main.create(wl.Registry);
			const wl_compositor = try allocator.main.create(wl.Compositor);
			const wl_seat = try allocator.main.create(wl.Seat);
			const wl_surface = try allocator.main.create(wl.Surface);
			const xdg_wm_base = try allocator.main.create(xdg.WmBase);
			const xdg_surface = try allocator.main.create(xdg.Surface);
			const xdg_toplevel = try allocator.main.create(xdg.Toplevel);
			const zwp_linux_dmabuf_v1 = try allocator.main.create(zwp.LinuxDmabufV1);
			const zwp_linux_dmabuf_feedback_v1 = try allocator.main.create(zwp.LinuxDmabufFeedbackV1);
			const zwp_linux_buffer_params_v1 = try allocator.main.create(zwp.LinuxBufferParamsV1);

			const wl_buffer = try allocator.main.create(Buffer);

			wl_display.error_callback = wl_display_error;
			wl_display.delete_id_callback = wl_display_delete_id;

			wl_registry.global_callback = wl_registry_global;
			wl_registry.global_remove_callback = wl_registry_global_remove;

			wl_seat.capabilities_callback = wl_seat_capabilities;
			wl_seat.name_callback = wl_seat_name;

			wl_surface.enter_callback = wl_surface_enter;
			wl_surface.leave_callback = wl_surface_leave;
			wl_surface.preferred_buffer_scale_callback = wl_surface_preferred_buffer_scale;
			wl_surface.preferred_buffer_transform_callback = wl_surface_preferred_buffer_transform;

			wl_buffer.handle.release_callback = wl_buffer_release;

			xdg_wm_base.ping_callback = xdg_wm_base_ping;

			xdg_surface.configure_callback = xdg_surface_configure;

			xdg_toplevel.configure_callback = xdg_toplevel_configure;
			xdg_toplevel.close_callback = xdg_toplevel_close;
			xdg_toplevel.configure_bounds_callback = xdg_toplevel_configure_bounds;
			xdg_toplevel.wm_capabilities_callback = xdg_toplevel_wm_capabilities;

			zwp_linux_dmabuf_v1.format_callback = zwp_linux_dmabuf_v1_format;
			zwp_linux_dmabuf_v1.modifier_callback = zwp_linux_dmabuf_v1_modifier;

			zwp_linux_dmabuf_feedback_v1.done_callback = zwp_linux_dmabuf_feedback_v1_done;
			zwp_linux_dmabuf_feedback_v1.format_table_callback = zwp_linux_dmabuf_feedback_v1_format_table;
			zwp_linux_dmabuf_feedback_v1.main_device_callback = zwp_linux_dmabuf_feedback_v1_main_device;
			zwp_linux_dmabuf_feedback_v1.tranche_done_callback = zwp_linux_dmabuf_feedback_v1_tranche_done;
			zwp_linux_dmabuf_feedback_v1.tranche_target_device_callback = zwp_linux_dmabuf_feedback_v1_tranche_target_device;
			zwp_linux_dmabuf_feedback_v1.tranche_formats_callback = zwp_linux_dmabuf_feedback_v1_tranche_formats;
			zwp_linux_dmabuf_feedback_v1.tranche_flags_callback = zwp_linux_dmabuf_feedback_v1_tranche_flags;

			zwp_linux_buffer_params_v1.created_callback = zwp_linux_buffer_params_v1_created;
			zwp_linux_buffer_params_v1.failed_callback = zwp_linux_buffer_params_v1_failed;

			wl_buffer.released = true;

			const self = try allocator.main.create(Self);
			self.functions = try std.ArrayList(Function).initCapacity(allocator.main, 100);
			self.ptrs = try std.ArrayList(*anyopaque).initCapacity(allocator.main, 50);
			self.writer = Writer.init(try allocator.main.alloc(u8, 4096));
			self.reader = Reader.init(try allocator.main.alloc(u8, 4096));
			self.socket = socket;
			self.width = width;
			self.height = height;
			self.running = false;
			self.drm_formats = try allocator.main.alloc(DrmFormat, 20);
			self.wl_buffer = wl_buffer;

			self.wl_display = wl_display;
			self.wl_registry = wl_registry;
			self.wl_compositor = wl_compositor;
			self.wl_seat = wl_seat;
			self.wl_surface = wl_surface;
			self.xdg_wm_base = xdg_wm_base;
			self.xdg_surface = xdg_surface;
			self.xdg_toplevel = xdg_toplevel;
			self.zwp_linux_dmabuf_v1 = zwp_linux_dmabuf_v1;
			self.zwp_linux_dmabuf_feedback_v1 = zwp_linux_dmabuf_feedback_v1;
			self.zwp_linux_buffer_params_v1 = zwp_linux_buffer_params_v1;

			try self.alloc(wl.Display, wl_display);
			try self.alloc(wl.Registry, wl_registry);

			wl_display.get_registry_request(&self.writer, wl_registry.id);

			try self.send_message(allocator);
			try self.read_message(allocator);
			try self.send_message(allocator);
			try self.read_message(allocator);
		}

		pub fn alloc(self: *Self, K: type, item: *K) !void {
			item.id = @intCast(self.ptrs.items.len + 1);

			std.debug.print("ASSIGNING ID: {d}\n", .{item.id});

			try self.functions.appendBounded(K.event);
			try self.ptrs.appendBounded(item);
		}

		pub fn read_message(self: *Self, allocator: *Allocator) !void {
			var io = std.posix.iovec {
				.base = self.reader.data[self.reader.offset..].ptr,
				.len = @intCast(self.reader.size - self.reader.offset),
			};

			const fd_align = std.mem.alignForward(usize, @sizeOf(Fd) * 10, @sizeOf(usize));
			const cmsg_align = std.mem.alignForward(usize, @sizeOf(cmsghdr), @sizeOf(usize));

			var header = Writer.init(try allocator.tmp.alignedAlloc(u8, .of(cmsghdr), cmsg_align + fd_align));
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

			self.reader.data.len += @intCast(size);

			if (msg.controllen > 0) {
				const fd_count = (cmsg.len - msg_header_size) / @sizeOf(Fd);

				const fd_ptrs: [*]Fd = @ptrCast(@alignCast(header.data[msg_header_size..msg_header_size + @sizeOf(Fd) * fd_count].ptr));
				const fds = fd_ptrs[0..fd_count];

				try self.reader.fds.appendSlice(allocator.main, fds);
			}

			while (try self.decode()) {}
		}

		pub fn send_message(self: *Self, allocator: *Allocator) !void {
			if (self.writer.offset == 0) {
				return;
			}

			std.debug.print("{any}\n", .{self.writer.data[0..self.writer.offset]});

			var io = std.posix.iovec {
				.base = self.writer.data.ptr,
				.len = @intCast(self.writer.offset),
			};

			const cmsg_align: usize = @intCast(std.mem.alignForward(usize, @sizeOf(cmsghdr), @sizeOf(usize)));
			const fd_size: usize = @intCast(self.writer.fds.items.len * @sizeOf(Fd));

			var cmsg: cmsghdr = std.mem.zeroes(cmsghdr);
			cmsg.len = @intCast(cmsg_align + fd_size);
			cmsg.type = c.SCM_RIGHTS;
			cmsg.level = c.SOL_SOCKET;

			var header = Writer.init(try allocator.tmp.alloc(u8, 1024));
			header.write_raw(cmsghdr, cmsg);
			header.padd(cmsg_align - @sizeOf(cmsghdr));
			header.append(Fd, self.writer.fds.items);

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
			self.writer.fds.clearRetainingCapacity();
		}

		fn decode(self: *Self) !bool {
			if (self.reader.data.len <= @sizeOf(usize) + self.reader.offset) return false;

			const obj = self.reader.read_object() - 1;

			if (self.ptrs.items.len <= obj) {
				return error.OutOfBounds;
			}

			self.functions.items[obj](self.ptrs.items[obj], self, &self.reader);
			return true;
		}

		fn buffer_create(self: *Self, width: usize, height: usize, index: usize) void {
			self.zwp_linux_dmabuf_v1.create_param_request(&self.writer, self.zwp_dmabuf_v1_params);

			const frame = self.frames[index];

			for (frame.modifier.drmFormatModifierPlaneCount) |i| {
				const plane = frame.planes[i];

				const modifier_hi = frame.modifier.drmFormatModifier & 0xFFFFFFFF00000000;
				const modifier_lo = frame.modifier.drmFormatModifier & 0x00000000FFFFFFFF;

				self.zwp_linux_dmabuf_v1_params.add_request(&self.writer, frame.fd, @intCast(i), @intCast(plane.offset), @intCast(plane.rowPitch), @intCast(modifier_hi), @intCast(modifier_lo));
			}

			const format = frame.drm_format;
			const buffer = self.wl_buffer;

			self.zwp_linux_dmabuf_v1_params.create_immed_request(&self.writer, buffer.handle.id, @intCast(width), @intCast(height), @intCast(format), @intCast(0));

			self.zwp_linux_dmabuf_v1_params.destroy_request(&self.writer);
		}

		fn wl_display_error(self: *Self, display: *wl.Display, object: Object, code: Uint, message: String) void {
			std.debug.print("display_error -> object: {d}, code: {d}, message: {s}\n", .{object, code, message});
			_ = self;
			_ = display;
			// _ = object;
			// _ = code;
			// _ = message;

			std.debug.print("An error has occured\n", .{});	
		}

		fn wl_display_delete_id(self: *Self, display: *wl.Display, id: Uint) void {
			std.debug.print("display_delete_id\n", .{});
			_ = self;
			_ = display;
			_ = id;
		}

		fn wl_registry_global(self: *Self, registry: *wl.Registry, name: Uint, interface: String, version: Uint) void {
			std.debug.print("hello global: name: {d}, version: {d}, interface: {s}\n", .{name, version, interface});

			if (std.mem.eql(u8, interface, xdg.WmBase.interface_name)) {
				// self.alloc(xdg.WmBase, self.xdg_wm_base) catch @panic("OUT OF MEMORY");
				// registry.bind_request(&self.writer, name, .{.interface = interface, .id = self.xdg_wm_base.id, .version = version});

				//self.alloc(xdg.Surface, self.xdg_surface) catch @panic("FILED TO ASSIGN INTERFACE ID");
				//self.xdg_wm_base.get_xdg_surface_request(&self.writer, self.xdg_surface.id, self.wl_surface.id);

				//self.alloc(xdg.Toplevel, self.xdg_toplevel) catch @panic("FILED TO ASSIGN INTERFACE ID");
				//self.xdg_surface.get_toplevel_request(&self.writer, self.xdg_toplevel.id);

				//self.wl_surface.commit_request(&self.writer);
			} else if (std.mem.eql(u8, interface, wl.Compositor.interface_name)) {
				self.alloc(wl.Compositor, self.wl_compositor) catch @panic("FAILED TO ASSIGN INTERFACE ID");
				registry.bind_request(&self.writer, name, .{.interface = interface, .id = self.wl_compositor.id, .version = version});

				// self.alloc(wl.Surface, self.wl_surface) catch @panic("FAILED TO ASSIGN ID");
				// self.wl_compositor.create_surface_request(&self.writer, self.wl_surface.id);

				// self.alloc(zwp.LinuxDmabufFeedbackV1, self.zwp_linux_dmabuf_feedback_v1) catch @panic("FAILED TO ASSIGN INTERFACE ID");
				// self.zwp_linux_dmabuf_v1.get_surface_feedback_request(&self.writer, self.zwp_linux_dmabuf_feedback_v1.id, self.wl_surface.id);
			} else if (std.mem.eql(u8, interface, wl.Seat.interface_name)) {
				// self.alloc(wl.Seat, self.wl_seat) catch @panic("FAILED TO ASSIGN INTERFACE ID");
				// registry.bind_request(&self.writer, name, .{.interface = interface, .id = self.wl_seat.id, .version = version});
			} else if (std.mem.eql(u8, interface, zwp.LinuxDmabufV1.interface_name)) {
				// self.alloc(zwp.LinuxDmabufV1, self.zwp_linux_dmabuf_v1) catch @panic("FAILED TO ASSIGN INTERFACE ID");
				// registry.bind_request(&self.writer, name, .{.interface = interface, .id = self.zwp_linux_dmabuf_v1.id, .version = version});
			}
		}

		fn wl_registry_global_remove(self: *Self, registry: *wl.Registry, name: Uint) void {
			std.debug.print("registry_global_remove\n", .{});
			_ = self;
			_ = registry;
			_ = name;
		}

		fn wl_seat_capabilities(self: *Self, seat: *wl.Seat, capabilities: Uint) void {
			std.debug.print("seat_capabilities\n", .{});
			_ = self;
			_ = seat;
			_ = capabilities;
		}

		fn wl_seat_name(self: *Self, seat: *wl.Seat, name: String) void {
			std.debug.print("seat_name\n", .{});
			_ = self;
			_ = seat;
			_ = name;
		}

		fn wl_surface_enter(self: *Self, surface: *wl.Surface, output: Object) void {
				std.debug.print("wl_surface_enter\n", .{});
			_ = self;
			_ = surface;
			_ = output;
		}

		fn wl_surface_leave(self: *Self, surface: *wl.Surface, output: Object) void {
				std.debug.print("wl_surface_leave\n", .{});
			_ = self;
			_ = surface;
			_ = output;
		}

		fn wl_surface_preferred_buffer_scale(self: *Self, surface: *wl.Surface, factor: Int) void {
				std.debug.print("wl_surface_preferred_buffer_scale\n", .{});
			_ = self;
			_ = surface;
			_ = factor;
		}

		fn wl_surface_preferred_buffer_transform(self: *Self, surface: *wl.Surface, transform: Uint) void {
				std.debug.print("wl_surface_preferred_buffer_transform\n", .{});
			_ = self;
			_ = surface;
			_ = transform;
		}

		fn wl_buffer_release(self: *Self, buffer: *wl.Buffer) void {
				std.debug.print("wl_buffer_release\n", .{});
			_ = self;
			const parent: *Buffer = @fieldParentPtr("handle", buffer);
			parent.released = true;
		}

		fn xdg_wm_base_ping(self: *Self, wm_base: *xdg.WmBase, serial: Uint) void {
				std.debug.print("xdg_wm_base_ping\n", .{});
			wm_base.pong_request(&self.writer, serial);
		}

		fn xdg_surface_configure(self: *Self, surface: *xdg.Surface, serial: Uint) void {
				std.debug.print("xdg_surface_configure\n", .{});
			surface.ack_configure_request(&self.writer, serial);
		}

		fn xdg_toplevel_configure(self: *Self, toplevel: *xdg.Toplevel, width: Int, height: Int, states: Array) void {
				std.debug.print("xdg_toplevel_configure\n", .{});
			_ = toplevel;
			_ = states;

			if (width <= 0 or height <= 0) return;
			if (width == self.width and height == self.height) return;

			self.width = @intCast(width);
			self.height = @intCast(height);
		}

		fn xdg_toplevel_close(self: *Self, toplevel: *xdg.Toplevel) void {
				std.debug.print("xdg_toplevel_close\n", .{});
			_ = toplevel;
			self.running = false;
		}

		fn xdg_toplevel_configure_bounds(self: *Self, toplevel: *xdg.Toplevel, width: Int, height: Int) void {
				std.debug.print("xdg_toplevel_configure_bounds\n", .{});
			_ = self;
			_ = toplevel;
			_ = width;
			_ = height;
		}

		fn xdg_toplevel_wm_capabilities(self: *Self, toplevel: *xdg.Toplevel, capabilities: Array) void {
				std.debug.print("xdg_toplevel_wm_capabilities\n", .{});
			_ = self;
			_ = toplevel;
			_ = capabilities;
		}

		fn zwp_linux_dmabuf_v1_format(self: *Self, linux_dmabuf_v1: *zwp.LinuxDmabufV1, format: Uint) void {
				std.debug.print("zwp_linux_dmabuf_v1_format\n", .{});
			_ = self;
			_ = linux_dmabuf_v1;
			_ = format;
		}

		fn zwp_linux_dmabuf_v1_modifier(self: *Self, linux_dmabuf_v1: *zwp.LinuxDmabufV1, format: Uint, modifier_hi: Uint, modifier_lo: Uint) void {
				std.debug.print("zwp_linux_dmabuf_v1_modifier\n", .{});
			_ = self;
			_ = linux_dmabuf_v1;
			_ = format;
			_ = modifier_hi;
			_ = modifier_lo;
		}

		fn zwp_linux_dmabuf_feedback_v1_done(self: *Self, dmabuf_feedback: *zwp.LinuxDmabufFeedbackV1) void {
				std.debug.print("zwp_linux_dmabuf_feedback_v1_done\n", .{});
			_ = self;
			_ = dmabuf_feedback;
		}

		fn zwp_linux_dmabuf_feedback_v1_format_table(self: *Self, dmabuf_feedback: *zwp.LinuxDmabufFeedbackV1, fd: Fd, size: Uint) void {
				std.debug.print("zwp_linux_dmabuf_feedback_v1_format_table\n", .{});
			_ = dmabuf_feedback;
			const buffer = std.posix.mmap(null, size, std.posix.PROT.READ, .{.TYPE = .PRIVATE }, fd, 0) catch @panic("MMAP");
			defer std.posix.munmap(buffer);

			var reader = Reader.init(buffer);

			const count = size / std.mem.alignForward(usize, @sizeOf(u32) + @sizeOf(u64), @sizeOf(u64));

			for (0..count) |i| {
				const format = reader.read_raw(u32);
				const padding = reader.read_raw(u32);
				const modifier = reader.read_raw(u64);
				_ = padding;

				self.drm_formats[i] = .{ .modifier = modifier, .format = format };
			}
		}

		fn zwp_linux_dmabuf_feedback_v1_main_device(self: *Self, dmabuf_feedback: *zwp.LinuxDmabufFeedbackV1, device: Array) void {
				std.debug.print("zwp_linux_dmabuf_feedback_v1_main_device\n", .{});
			_ = self;
			_ = dmabuf_feedback;
			_ = device;
		}

		fn zwp_linux_dmabuf_feedback_v1_tranche_done(self: *Self, dmabuf_feedback: *zwp.LinuxDmabufFeedbackV1) void {
				std.debug.print("zwp_linux_dmabuf_feedback_v1_tranche_done\n", .{});
			dmabuf_feedback.destroy_request(&self.writer);
		}

		fn zwp_linux_dmabuf_feedback_v1_tranche_target_device(self: *Self, dmabuf_feedback: *zwp.LinuxDmabufFeedbackV1, device: Array) void {
				std.debug.print("zwp_linux_dmabuf_feedback_v1_tranche_target_device\n", .{});
			_ = dmabuf_feedback;
			const indices = std.mem.bytesAsSlice(u16, device);

			for (indices, 0..) |idx, i| {
				self.drm_formats[i] = self.drm_formats[idx];
			}
		}

		fn zwp_linux_dmabuf_feedback_v1_tranche_formats(self: *Self, dmabuf_feedback: *zwp.LinuxDmabufFeedbackV1, indices: Array) void {
				std.debug.print("zwp_linux_dmabuf_feedback_v1_tranche_formats\n", .{});
			_ = self;
			_ = dmabuf_feedback;
			_ = indices;
		}

		fn zwp_linux_dmabuf_feedback_v1_tranche_flags(self: *Self, dmabuf_feedback: *zwp.LinuxDmabufFeedbackV1, flags: Uint) void {
				std.debug.print("zwp_linux_dmabuf_feedback_v1_tranche_flags\n", .{});
			_ = self;
			_ = dmabuf_feedback;
			_ = flags;
		}

		fn zwp_linux_buffer_params_v1_created(self: *Self, zwp_linux_dmbuf_params_v1: *zwp.LinuxBufferParamsV1, buffer: NewId) void {
				std.debug.print("zwp_linux_buffer_params_v1_created\n", .{});
			_ = self;
			_ = zwp_linux_dmbuf_params_v1;
			_ = buffer;
		}

		fn zwp_linux_buffer_params_v1_failed(self: *Self, zwp_linux_dmbuf_params_v1: *zwp.LinuxBufferParamsV1) void {
				std.debug.print("zwp_linux_buffer_params_v1_failed\n", .{});
			_ = self;
			_ = zwp_linux_dmbuf_params_v1;
		}
	};
}
	
pub const Reader = struct {
	data: []u8,
	offset: usize,
	size: usize,
	fds: std.ArrayList(Fd),
	fd_offset: usize,

	pub fn init(data: []u8) Reader {
		const size = data.len;
		var d = data;
		d.len = 0;

		 return .{
			.data = d,
			.offset = 0,
			.size = size,
			.fds = std.ArrayList(Fd) {},
			.fd_offset = 0,
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

	pub fn read_fd(self: *Reader) Fd {
		defer self.fd_offset += 1;
		return self.fds.items[self.fd_offset];
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
	fds: std.ArrayList(Fd),

	pub fn init(data: []u8) Writer {
		return .{
			.data = data,
			.offset = 0,
			.fds = std.ArrayList(Fd) {},
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
