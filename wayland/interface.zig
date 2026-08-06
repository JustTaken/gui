const root = @import("root.zig");
const Int = root.Int;
const Uint = root.Uint;
const Fixed = root.Fixed;
const Object = root.Object;
const Fd = root.Fd;
const String = root.String;
const Array = root.Array;
const NewId = root.NewId;
const UnboundedNewId = root.UnboundedNewId;
const Id = root.Id;
const Writer = root.Writer;
const Reader = root.Reader;

pub fn Interface(T: type) type {
	return struct {
		pub const Wl = struct {
			pub const Display = struct {
				id: Id,
				event: *const fn(*T, *Display, Event) void,

				const Event = union(enum) {
					error_event: struct { object: Object, opcode: Uint,  message: String },

				};
			};
		};
	};
}
pub fn Wl(T: type) type {
	return struct {
		pub const Display = struct {
			id: Id,
			error_callback: *const fn(*T, *Display, Object, Uint, String) void,
			delete_id_callback: *const fn(*T, *Display, Uint) void,
			pub const interface_name = "wl_display";
			pub const interface_version = "1";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				switch (opcode) {
					0 => error_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					1 => delete_id_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					 else => @panic("Unknown opcode"),
				}
			}
			pub const Error = enum(Uint) {
				@"invalid_object" = 0,
				@"invalid_method" = 1,
				@"no_memory" = 2,
				@"implementation" = 3,
			};
			pub fn error_event(self: *Display, ptr: *T, reader: *Reader) void {
				const object_id = reader.read_object();
				const code = reader.read_uint();
				const message = reader.read_string();
				self.error_callback(ptr, self, object_id, code, message);
			}
			pub fn delete_id_event(self: *Display, ptr: *T, reader: *Reader) void {
				const id = reader.read_uint();
				self.delete_id_callback(ptr, self, id);
			}
			pub fn sync_request(self: *const Display, writer: *Writer, callback: NewId) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_new_id(callback);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn get_registry_request(self: *const Display, writer: *Writer, registry: NewId) void {
				const opcode = 1;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_new_id(registry);
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const Registry = struct {
			id: Id,
			global_callback: *const fn(*T, *Registry, Uint, String, Uint) void,
			global_remove_callback: *const fn(*T, *Registry, Uint) void,
			pub const interface_name = "wl_registry";
			pub const interface_version = "1";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				switch (opcode) {
					0 => global_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					1 => global_remove_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					 else => @panic("Unknown opcode"),
				}
			}
			pub fn global_event(self: *Registry, ptr: *T, reader: *Reader) void {
				const name = reader.read_uint();
				const interface = reader.read_string();
				const version = reader.read_uint();
				self.global_callback(ptr, self, name, interface, version);
			}
			pub fn global_remove_event(self: *Registry, ptr: *T, reader: *Reader) void {
				const name = reader.read_uint();
				self.global_remove_callback(ptr, self, name);
			}
			pub fn bind_request(self: *const Registry, writer: *Writer, name: Uint, id: UnboundedNewId) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_uint(name);
				writer.write_unbounded_new_id(id);
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const Callback = struct {
			id: Id,
			done_callback: *const fn(*T, *Callback, Uint) void,
			pub const interface_name = "wl_callback";
			pub const interface_version = "1";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				switch (opcode) {
					0 => done_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					 else => @panic("Unknown opcode"),
				}
			}
			pub fn done_event(self: *Callback, ptr: *T, reader: *Reader) void {
				const callback_data = reader.read_uint();
				self.done_callback(ptr, self, callback_data);
			}
		};
		pub const Compositor = struct {
			id: Id,
			pub const interface_name = "wl_compositor";
			pub const interface_version = "6";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				_ = self_ptr;
				_ = ptr;
				switch (opcode) {
					 else => @panic("Unknown opcode"),
				}
			}
			pub fn create_surface_request(self: *const Compositor, writer: *Writer, id: NewId) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_new_id(id);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn create_region_request(self: *const Compositor, writer: *Writer, id: NewId) void {
				const opcode = 1;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_new_id(id);
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const ShmPool = struct {
			id: Id,
			pub const interface_name = "wl_shm_pool";
			pub const interface_version = "2";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				_ = self_ptr;
				_ = ptr;
				switch (opcode) {
					 else => @panic("Unknown opcode"),
				}
			}
			pub fn create_buffer_request(self: *const ShmPool, writer: *Writer, id: NewId, offset: Int, width: Int, height: Int, stride: Int, format: Uint) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_new_id(id);
				writer.write_int(offset);
				writer.write_int(width);
				writer.write_int(height);
				writer.write_int(stride);
				writer.write_uint(format);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn destroy_request(self: *const ShmPool, writer: *Writer) void {
				const opcode = 1;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn resize_request(self: *const ShmPool, writer: *Writer, size: Int) void {
				const opcode = 2;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_int(size);
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const Shm = struct {
			id: Id,
			format_callback: *const fn(*T, *Shm, Uint) void,
			pub const interface_name = "wl_shm";
			pub const interface_version = "2";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				switch (opcode) {
					0 => format_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					 else => @panic("Unknown opcode"),
				}
			}
			pub const Error = enum(Uint) {
				@"invalid_format" = 0,
				@"invalid_stride" = 1,
				@"invalid_fd" = 2,
			};
			pub const Format = enum(Uint) {
				@"argb8888" = 0,
				@"xrgb8888" = 1,
				@"c8" = 0x20203843,
				@"rgb332" = 0x38424752,
				@"bgr233" = 0x38524742,
				@"xrgb4444" = 0x32315258,
				@"xbgr4444" = 0x32314258,
				@"rgbx4444" = 0x32315852,
				@"bgrx4444" = 0x32315842,
				@"argb4444" = 0x32315241,
				@"abgr4444" = 0x32314241,
				@"rgba4444" = 0x32314152,
				@"bgra4444" = 0x32314142,
				@"xrgb1555" = 0x35315258,
				@"xbgr1555" = 0x35314258,
				@"rgbx5551" = 0x35315852,
				@"bgrx5551" = 0x35315842,
				@"argb1555" = 0x35315241,
				@"abgr1555" = 0x35314241,
				@"rgba5551" = 0x35314152,
				@"bgra5551" = 0x35314142,
				@"rgb565" = 0x36314752,
				@"bgr565" = 0x36314742,
				@"rgb888" = 0x34324752,
				@"bgr888" = 0x34324742,
				@"xbgr8888" = 0x34324258,
				@"rgbx8888" = 0x34325852,
				@"bgrx8888" = 0x34325842,
				@"abgr8888" = 0x34324241,
				@"rgba8888" = 0x34324152,
				@"bgra8888" = 0x34324142,
				@"xrgb2101010" = 0x30335258,
				@"xbgr2101010" = 0x30334258,
				@"rgbx1010102" = 0x30335852,
				@"bgrx1010102" = 0x30335842,
				@"argb2101010" = 0x30335241,
				@"abgr2101010" = 0x30334241,
				@"rgba1010102" = 0x30334152,
				@"bgra1010102" = 0x30334142,
				@"yuyv" = 0x56595559,
				@"yvyu" = 0x55595659,
				@"uyvy" = 0x59565955,
				@"vyuy" = 0x59555956,
				@"ayuv" = 0x56555941,
				@"nv12" = 0x3231564e,
				@"nv21" = 0x3132564e,
				@"nv16" = 0x3631564e,
				@"nv61" = 0x3136564e,
				@"yuv410" = 0x39565559,
				@"yvu410" = 0x39555659,
				@"yuv411" = 0x31315559,
				@"yvu411" = 0x31315659,
				@"yuv420" = 0x32315559,
				@"yvu420" = 0x32315659,
				@"yuv422" = 0x36315559,
				@"yvu422" = 0x36315659,
				@"yuv444" = 0x34325559,
				@"yvu444" = 0x34325659,
				@"r8" = 0x20203852,
				@"r16" = 0x20363152,
				@"rg88" = 0x38384752,
				@"gr88" = 0x38385247,
				@"rg1616" = 0x32334752,
				@"gr1616" = 0x32335247,
				@"xrgb16161616f" = 0x48345258,
				@"xbgr16161616f" = 0x48344258,
				@"argb16161616f" = 0x48345241,
				@"abgr16161616f" = 0x48344241,
				@"xyuv8888" = 0x56555958,
				@"vuy888" = 0x34325556,
				@"vuy101010" = 0x30335556,
				@"y210" = 0x30313259,
				@"y212" = 0x32313259,
				@"y216" = 0x36313259,
				@"y410" = 0x30313459,
				@"y412" = 0x32313459,
				@"y416" = 0x36313459,
				@"xvyu2101010" = 0x30335658,
				@"xvyu12_16161616" = 0x36335658,
				@"xvyu16161616" = 0x38345658,
				@"y0l0" = 0x304c3059,
				@"x0l0" = 0x304c3058,
				@"y0l2" = 0x324c3059,
				@"x0l2" = 0x324c3058,
				@"yuv420_8bit" = 0x38305559,
				@"yuv420_10bit" = 0x30315559,
				@"xrgb8888_a8" = 0x38415258,
				@"xbgr8888_a8" = 0x38414258,
				@"rgbx8888_a8" = 0x38415852,
				@"bgrx8888_a8" = 0x38415842,
				@"rgb888_a8" = 0x38413852,
				@"bgr888_a8" = 0x38413842,
				@"rgb565_a8" = 0x38413552,
				@"bgr565_a8" = 0x38413542,
				@"nv24" = 0x3432564e,
				@"nv42" = 0x3234564e,
				@"p210" = 0x30313250,
				@"p010" = 0x30313050,
				@"p012" = 0x32313050,
				@"p016" = 0x36313050,
				@"axbxgxrx106106106106" = 0x30314241,
				@"nv15" = 0x3531564e,
				@"q410" = 0x30313451,
				@"q401" = 0x31303451,
				@"xrgb16161616" = 0x38345258,
				@"xbgr16161616" = 0x38344258,
				@"argb16161616" = 0x38345241,
				@"abgr16161616" = 0x38344241,
				@"c1" = 0x20203143,
				@"c2" = 0x20203243,
				@"c4" = 0x20203443,
				@"d1" = 0x20203144,
				@"d2" = 0x20203244,
				@"d4" = 0x20203444,
				@"d8" = 0x20203844,
				@"r1" = 0x20203152,
				@"r2" = 0x20203252,
				@"r4" = 0x20203452,
				@"r10" = 0x20303152,
				@"r12" = 0x20323152,
				@"avuy8888" = 0x59555641,
				@"xvuy8888" = 0x59555658,
				@"p030" = 0x30333050,
			};
			pub fn format_event(self: *Shm, ptr: *T, reader: *Reader) void {
				const format = reader.read_uint();
				self.format_callback(ptr, self, format);
			}
			pub fn create_pool_request(self: *const Shm, writer: *Writer, id: NewId, fd: Fd, size: Int) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_new_id(id);
				writer.write_fd(fd);
				writer.write_int(size);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn release_request(self: *const Shm, writer: *Writer) void {
				const opcode = 1;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const Buffer = struct {
			id: Id,
			release_callback: *const fn(*T, *Buffer) void,
			pub const interface_name = "wl_buffer";
			pub const interface_version = "1";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				switch (opcode) {
					0 => release_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					 else => @panic("Unknown opcode"),
				}
			}
			pub fn release_event(self: *Buffer, ptr: *T, reader: *Reader) void {
			_ = reader;
				self.release_callback(ptr, self);
			}
			pub fn destroy_request(self: *const Buffer, writer: *Writer) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const DataOffer = struct {
			id: Id,
			offer_callback: *const fn(*T, *DataOffer, String) void,
			source_actions_callback: *const fn(*T, *DataOffer, Uint) void,
			action_callback: *const fn(*T, *DataOffer, Uint) void,
			pub const interface_name = "wl_data_offer";
			pub const interface_version = "3";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				switch (opcode) {
					0 => offer_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					1 => source_actions_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					2 => action_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					 else => @panic("Unknown opcode"),
				}
			}
			pub const Error = enum(Uint) {
				@"invalid_finish" = 0,
				@"invalid_action_mask" = 1,
				@"invalid_action" = 2,
				@"invalid_offer" = 3,
			};
			pub fn offer_event(self: *DataOffer, ptr: *T, reader: *Reader) void {
				const mime_type = reader.read_string();
				self.offer_callback(ptr, self, mime_type);
			}
			pub fn source_actions_event(self: *DataOffer, ptr: *T, reader: *Reader) void {
				const source_actions = reader.read_uint();
				self.source_actions_callback(ptr, self, source_actions);
			}
			pub fn action_event(self: *DataOffer, ptr: *T, reader: *Reader) void {
				const dnd_action = reader.read_uint();
				self.action_callback(ptr, self, dnd_action);
			}
			pub fn accept_request(self: *const DataOffer, writer: *Writer, serial: Uint, mime_type: String) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_uint(serial);
				writer.write_string(mime_type);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn receive_request(self: *const DataOffer, writer: *Writer, mime_type: String, fd: Fd) void {
				const opcode = 1;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_string(mime_type);
				writer.write_fd(fd);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn destroy_request(self: *const DataOffer, writer: *Writer) void {
				const opcode = 2;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn finish_request(self: *const DataOffer, writer: *Writer) void {
				const opcode = 3;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_actions_request(self: *const DataOffer, writer: *Writer, dnd_actions: Uint, preferred_action: Uint) void {
				const opcode = 4;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_uint(dnd_actions);
				writer.write_uint(preferred_action);
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const DataSource = struct {
			id: Id,
			target_callback: *const fn(*T, *DataSource, String) void,
			send_callback: *const fn(*T, *DataSource, String, Fd) void,
			cancelled_callback: *const fn(*T, *DataSource) void,
			dnd_drop_performed_callback: *const fn(*T, *DataSource) void,
			dnd_finished_callback: *const fn(*T, *DataSource) void,
			action_callback: *const fn(*T, *DataSource, Uint) void,
			pub const interface_name = "wl_data_source";
			pub const interface_version = "3";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				switch (opcode) {
					0 => target_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					1 => send_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					2 => cancelled_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					3 => dnd_drop_performed_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					4 => dnd_finished_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					5 => action_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					 else => @panic("Unknown opcode"),
				}
			}
			pub const Error = enum(Uint) {
				@"invalid_action_mask" = 0,
				@"invalid_source" = 1,
			};
			pub fn target_event(self: *DataSource, ptr: *T, reader: *Reader) void {
				const mime_type = reader.read_string();
				self.target_callback(ptr, self, mime_type);
			}
			pub fn send_event(self: *DataSource, ptr: *T, reader: *Reader) void {
				const mime_type = reader.read_string();
				const fd = reader.read_fd();
				self.send_callback(ptr, self, mime_type, fd);
			}
			pub fn cancelled_event(self: *DataSource, ptr: *T, reader: *Reader) void {
			_ = reader;
				self.cancelled_callback(ptr, self);
			}
			pub fn dnd_drop_performed_event(self: *DataSource, ptr: *T, reader: *Reader) void {
			_ = reader;
				self.dnd_drop_performed_callback(ptr, self);
			}
			pub fn dnd_finished_event(self: *DataSource, ptr: *T, reader: *Reader) void {
			_ = reader;
				self.dnd_finished_callback(ptr, self);
			}
			pub fn action_event(self: *DataSource, ptr: *T, reader: *Reader) void {
				const dnd_action = reader.read_uint();
				self.action_callback(ptr, self, dnd_action);
			}
			pub fn offer_request(self: *const DataSource, writer: *Writer, mime_type: String) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_string(mime_type);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn destroy_request(self: *const DataSource, writer: *Writer) void {
				const opcode = 1;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_actions_request(self: *const DataSource, writer: *Writer, dnd_actions: Uint) void {
				const opcode = 2;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_uint(dnd_actions);
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const DataDevice = struct {
			id: Id,
			data_offer_callback: *const fn(*T, *DataDevice, NewId) void,
			enter_callback: *const fn(*T, *DataDevice, Uint, Object, Fixed, Fixed, Object) void,
			leave_callback: *const fn(*T, *DataDevice) void,
			motion_callback: *const fn(*T, *DataDevice, Uint, Fixed, Fixed) void,
			drop_callback: *const fn(*T, *DataDevice) void,
			selection_callback: *const fn(*T, *DataDevice, Object) void,
			pub const interface_name = "wl_data_device";
			pub const interface_version = "3";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				switch (opcode) {
					0 => data_offer_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					1 => enter_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					2 => leave_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					3 => motion_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					4 => drop_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					5 => selection_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					 else => @panic("Unknown opcode"),
				}
			}
			pub const Error = enum(Uint) {
				@"role" = 0,
				@"used_source" = 1,
			};
			pub fn data_offer_event(self: *DataDevice, ptr: *T, reader: *Reader) void {
				const id = reader.read_new_id();
				self.data_offer_callback(ptr, self, id);
			}
			pub fn enter_event(self: *DataDevice, ptr: *T, reader: *Reader) void {
				const serial = reader.read_uint();
				const surface = reader.read_object();
				const x = reader.read_fixed();
				const y = reader.read_fixed();
				const id = reader.read_object();
				self.enter_callback(ptr, self, serial, surface, x, y, id);
			}
			pub fn leave_event(self: *DataDevice, ptr: *T, reader: *Reader) void {
			_ = reader;
				self.leave_callback(ptr, self);
			}
			pub fn motion_event(self: *DataDevice, ptr: *T, reader: *Reader) void {
				const time = reader.read_uint();
				const x = reader.read_fixed();
				const y = reader.read_fixed();
				self.motion_callback(ptr, self, time, x, y);
			}
			pub fn drop_event(self: *DataDevice, ptr: *T, reader: *Reader) void {
			_ = reader;
				self.drop_callback(ptr, self);
			}
			pub fn selection_event(self: *DataDevice, ptr: *T, reader: *Reader) void {
				const id = reader.read_object();
				self.selection_callback(ptr, self, id);
			}
			pub fn start_drag_request(self: *const DataDevice, writer: *Writer, source: Object, origin: Object, icon: Object, serial: Uint) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_object(source);
				writer.write_object(origin);
				writer.write_object(icon);
				writer.write_uint(serial);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_selection_request(self: *const DataDevice, writer: *Writer, source: Object, serial: Uint) void {
				const opcode = 1;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_object(source);
				writer.write_uint(serial);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn release_request(self: *const DataDevice, writer: *Writer) void {
				const opcode = 2;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const DataDeviceManager = struct {
			id: Id,
			pub const interface_name = "wl_data_device_manager";
			pub const interface_version = "3";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				_ = self_ptr;
				_ = ptr;
				switch (opcode) {
					 else => @panic("Unknown opcode"),
				}
			}
			pub const DndAction = enum(Uint) {
				@"none" = 0,
				@"copy" = 1,
				@"move" = 2,
				@"ask" = 4,
			};
			pub fn create_data_source_request(self: *const DataDeviceManager, writer: *Writer, id: NewId) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_new_id(id);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn get_data_device_request(self: *const DataDeviceManager, writer: *Writer, id: NewId, seat: Object) void {
				const opcode = 1;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_new_id(id);
				writer.write_object(seat);
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const Shell = struct {
			id: Id,
			pub const interface_name = "wl_shell";
			pub const interface_version = "1";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				_ = self_ptr;
				_ = ptr;
				switch (opcode) {
					 else => @panic("Unknown opcode"),
				}
			}
			pub const Error = enum(Uint) {
				@"role" = 0,
			};
			pub fn get_shell_surface_request(self: *const Shell, writer: *Writer, id: NewId, surface: Object) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_new_id(id);
				writer.write_object(surface);
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const ShellSurface = struct {
			id: Id,
			ping_callback: *const fn(*T, *ShellSurface, Uint) void,
			configure_callback: *const fn(*T, *ShellSurface, Uint, Int, Int) void,
			popup_done_callback: *const fn(*T, *ShellSurface) void,
			pub const interface_name = "wl_shell_surface";
			pub const interface_version = "1";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				switch (opcode) {
					0 => ping_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					1 => configure_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					2 => popup_done_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					 else => @panic("Unknown opcode"),
				}
			}
			pub const Resize = enum(Uint) {
				@"none" = 0,
				@"top" = 1,
				@"bottom" = 2,
				@"left" = 4,
				@"top_left" = 5,
				@"bottom_left" = 6,
				@"right" = 8,
				@"top_right" = 9,
				@"bottom_right" = 10,
			};
			pub const Transient = enum(Uint) {
				@"inactive" = 0x1,
			};
			pub const FullscreenMethod = enum(Uint) {
				@"default" = 0,
				@"scale" = 1,
				@"driver" = 2,
				@"fill" = 3,
			};
			pub fn ping_event(self: *ShellSurface, ptr: *T, reader: *Reader) void {
				const serial = reader.read_uint();
				self.ping_callback(ptr, self, serial);
			}
			pub fn configure_event(self: *ShellSurface, ptr: *T, reader: *Reader) void {
				const edges = reader.read_uint();
				const width = reader.read_int();
				const height = reader.read_int();
				self.configure_callback(ptr, self, edges, width, height);
			}
			pub fn popup_done_event(self: *ShellSurface, ptr: *T, reader: *Reader) void {
			_ = reader;
				self.popup_done_callback(ptr, self);
			}
			pub fn pong_request(self: *const ShellSurface, writer: *Writer, serial: Uint) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_uint(serial);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn move_request(self: *const ShellSurface, writer: *Writer, seat: Object, serial: Uint) void {
				const opcode = 1;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_object(seat);
				writer.write_uint(serial);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn resize_request(self: *const ShellSurface, writer: *Writer, seat: Object, serial: Uint, edges: Uint) void {
				const opcode = 2;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_object(seat);
				writer.write_uint(serial);
				writer.write_uint(edges);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_toplevel_request(self: *const ShellSurface, writer: *Writer) void {
				const opcode = 3;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_transient_request(self: *const ShellSurface, writer: *Writer, parent: Object, x: Int, y: Int, flags: Uint) void {
				const opcode = 4;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_object(parent);
				writer.write_int(x);
				writer.write_int(y);
				writer.write_uint(flags);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_fullscreen_request(self: *const ShellSurface, writer: *Writer, method: Uint, framerate: Uint, output: Object) void {
				const opcode = 5;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_uint(method);
				writer.write_uint(framerate);
				writer.write_object(output);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_popup_request(self: *const ShellSurface, writer: *Writer, seat: Object, serial: Uint, parent: Object, x: Int, y: Int, flags: Uint) void {
				const opcode = 6;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_object(seat);
				writer.write_uint(serial);
				writer.write_object(parent);
				writer.write_int(x);
				writer.write_int(y);
				writer.write_uint(flags);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_maximized_request(self: *const ShellSurface, writer: *Writer, output: Object) void {
				const opcode = 7;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_object(output);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_title_request(self: *const ShellSurface, writer: *Writer, title: String) void {
				const opcode = 8;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_string(title);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_class_request(self: *const ShellSurface, writer: *Writer, class_: String) void {
				const opcode = 9;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_string(class_);
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const Surface = struct {
			id: Id,
			enter_callback: *const fn(*T, *Surface, Object) void,
			leave_callback: *const fn(*T, *Surface, Object) void,
			preferred_buffer_scale_callback: *const fn(*T, *Surface, Int) void,
			preferred_buffer_transform_callback: *const fn(*T, *Surface, Uint) void,
			pub const interface_name = "wl_surface";
			pub const interface_version = "6";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				switch (opcode) {
					0 => enter_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					1 => leave_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					2 => preferred_buffer_scale_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					3 => preferred_buffer_transform_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					 else => @panic("Unknown opcode"),
				}
			}
			pub const Error = enum(Uint) {
				@"invalid_scale" = 0,
				@"invalid_transform" = 1,
				@"invalid_size" = 2,
				@"invalid_offset" = 3,
				@"defunct_role_object" = 4,
			};
			pub fn enter_event(self: *Surface, ptr: *T, reader: *Reader) void {
				const output = reader.read_object();
				self.enter_callback(ptr, self, output);
			}
			pub fn leave_event(self: *Surface, ptr: *T, reader: *Reader) void {
				const output = reader.read_object();
				self.leave_callback(ptr, self, output);
			}
			pub fn preferred_buffer_scale_event(self: *Surface, ptr: *T, reader: *Reader) void {
				const factor = reader.read_int();
				self.preferred_buffer_scale_callback(ptr, self, factor);
			}
			pub fn preferred_buffer_transform_event(self: *Surface, ptr: *T, reader: *Reader) void {
				const transform = reader.read_uint();
				self.preferred_buffer_transform_callback(ptr, self, transform);
			}
			pub fn destroy_request(self: *const Surface, writer: *Writer) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn attach_request(self: *const Surface, writer: *Writer, buffer: Object, x: Int, y: Int) void {
				const opcode = 1;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_object(buffer);
				writer.write_int(x);
				writer.write_int(y);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn damage_request(self: *const Surface, writer: *Writer, x: Int, y: Int, width: Int, height: Int) void {
				const opcode = 2;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_int(x);
				writer.write_int(y);
				writer.write_int(width);
				writer.write_int(height);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn frame_request(self: *const Surface, writer: *Writer, callback: NewId) void {
				const opcode = 3;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_new_id(callback);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_opaque_region_request(self: *const Surface, writer: *Writer, region: Object) void {
				const opcode = 4;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_object(region);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_input_region_request(self: *const Surface, writer: *Writer, region: Object) void {
				const opcode = 5;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_object(region);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn commit_request(self: *const Surface, writer: *Writer) void {
				const opcode = 6;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_buffer_transform_request(self: *const Surface, writer: *Writer, transform: Int) void {
				const opcode = 7;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_int(transform);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_buffer_scale_request(self: *const Surface, writer: *Writer, scale: Int) void {
				const opcode = 8;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_int(scale);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn damage_buffer_request(self: *const Surface, writer: *Writer, x: Int, y: Int, width: Int, height: Int) void {
				const opcode = 9;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_int(x);
				writer.write_int(y);
				writer.write_int(width);
				writer.write_int(height);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn offset_request(self: *const Surface, writer: *Writer, x: Int, y: Int) void {
				const opcode = 10;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_int(x);
				writer.write_int(y);
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const Seat = struct {
			id: Id,
			capabilities_callback: *const fn(*T, *Seat, Uint) void,
			name_callback: *const fn(*T, *Seat, String) void,
			pub const interface_name = "wl_seat";
			pub const interface_version = "10";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				switch (opcode) {
					0 => capabilities_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					1 => name_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					 else => @panic("Unknown opcode"),
				}
			}
			pub const Capability = enum(Uint) {
				@"pointer" = 1,
				@"keyboard" = 2,
				@"touch" = 4,
			};
			pub const Error = enum(Uint) {
				@"missing_capability" = 0,
			};
			pub fn capabilities_event(self: *Seat, ptr: *T, reader: *Reader) void {
				const capabilities = reader.read_uint();
				self.capabilities_callback(ptr, self, capabilities);
			}
			pub fn name_event(self: *Seat, ptr: *T, reader: *Reader) void {
				const name = reader.read_string();
				self.name_callback(ptr, self, name);
			}
			pub fn get_pointer_request(self: *const Seat, writer: *Writer, id: NewId) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_new_id(id);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn get_keyboard_request(self: *const Seat, writer: *Writer, id: NewId) void {
				const opcode = 1;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_new_id(id);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn get_touch_request(self: *const Seat, writer: *Writer, id: NewId) void {
				const opcode = 2;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_new_id(id);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn release_request(self: *const Seat, writer: *Writer) void {
				const opcode = 3;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const Pointer = struct {
			id: Id,
			enter_callback: *const fn(*T, *Pointer, Uint, Object, Fixed, Fixed) void,
			leave_callback: *const fn(*T, *Pointer, Uint, Object) void,
			motion_callback: *const fn(*T, *Pointer, Uint, Fixed, Fixed) void,
			button_callback: *const fn(*T, *Pointer, Uint, Uint, Uint, Uint) void,
			axis_callback: *const fn(*T, *Pointer, Uint, Uint, Fixed) void,
			frame_callback: *const fn(*T, *Pointer) void,
			axis_source_callback: *const fn(*T, *Pointer, Uint) void,
			axis_stop_callback: *const fn(*T, *Pointer, Uint, Uint) void,
			axis_discrete_callback: *const fn(*T, *Pointer, Uint, Int) void,
			axis_value120_callback: *const fn(*T, *Pointer, Uint, Int) void,
			axis_relative_direction_callback: *const fn(*T, *Pointer, Uint, Uint) void,
			pub const interface_name = "wl_pointer";
			pub const interface_version = "10";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				switch (opcode) {
					0 => enter_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					1 => leave_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					2 => motion_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					3 => button_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					4 => axis_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					5 => frame_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					6 => axis_source_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					7 => axis_stop_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					8 => axis_discrete_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					9 => axis_value120_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					10 => axis_relative_direction_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					 else => @panic("Unknown opcode"),
				}
			}
			pub const Error = enum(Uint) {
				@"role" = 0,
			};
			pub const ButtonState = enum(Uint) {
				@"released" = 0,
				@"pressed" = 1,
			};
			pub const Axis = enum(Uint) {
				@"vertical_scroll" = 0,
				@"horizontal_scroll" = 1,
			};
			pub const AxisSource = enum(Uint) {
				@"wheel" = 0,
				@"finger" = 1,
				@"continuous" = 2,
				@"wheel_tilt" = 3,
			};
			pub const AxisRelativeDirection = enum(Uint) {
				@"identical" = 0,
				@"inverted" = 1,
			};
			pub fn enter_event(self: *Pointer, ptr: *T, reader: *Reader) void {
				const serial = reader.read_uint();
				const surface = reader.read_object();
				const surface_x = reader.read_fixed();
				const surface_y = reader.read_fixed();
				self.enter_callback(ptr, self, serial, surface, surface_x, surface_y);
			}
			pub fn leave_event(self: *Pointer, ptr: *T, reader: *Reader) void {
				const serial = reader.read_uint();
				const surface = reader.read_object();
				self.leave_callback(ptr, self, serial, surface);
			}
			pub fn motion_event(self: *Pointer, ptr: *T, reader: *Reader) void {
				const time = reader.read_uint();
				const surface_x = reader.read_fixed();
				const surface_y = reader.read_fixed();
				self.motion_callback(ptr, self, time, surface_x, surface_y);
			}
			pub fn button_event(self: *Pointer, ptr: *T, reader: *Reader) void {
				const serial = reader.read_uint();
				const time = reader.read_uint();
				const button = reader.read_uint();
				const state = reader.read_uint();
				self.button_callback(ptr, self, serial, time, button, state);
			}
			pub fn axis_event(self: *Pointer, ptr: *T, reader: *Reader) void {
				const time = reader.read_uint();
				const axis = reader.read_uint();
				const value = reader.read_fixed();
				self.axis_callback(ptr, self, time, axis, value);
			}
			pub fn frame_event(self: *Pointer, ptr: *T, reader: *Reader) void {
			_ = reader;
				self.frame_callback(ptr, self);
			}
			pub fn axis_source_event(self: *Pointer, ptr: *T, reader: *Reader) void {
				const axis_source = reader.read_uint();
				self.axis_source_callback(ptr, self, axis_source);
			}
			pub fn axis_stop_event(self: *Pointer, ptr: *T, reader: *Reader) void {
				const time = reader.read_uint();
				const axis = reader.read_uint();
				self.axis_stop_callback(ptr, self, time, axis);
			}
			pub fn axis_discrete_event(self: *Pointer, ptr: *T, reader: *Reader) void {
				const axis = reader.read_uint();
				const discrete = reader.read_int();
				self.axis_discrete_callback(ptr, self, axis, discrete);
			}
			pub fn axis_value120_event(self: *Pointer, ptr: *T, reader: *Reader) void {
				const axis = reader.read_uint();
				const value120 = reader.read_int();
				self.axis_value120_callback(ptr, self, axis, value120);
			}
			pub fn axis_relative_direction_event(self: *Pointer, ptr: *T, reader: *Reader) void {
				const axis = reader.read_uint();
				const direction = reader.read_uint();
				self.axis_relative_direction_callback(ptr, self, axis, direction);
			}
			pub fn set_cursor_request(self: *const Pointer, writer: *Writer, serial: Uint, surface: Object, hotspot_x: Int, hotspot_y: Int) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_uint(serial);
				writer.write_object(surface);
				writer.write_int(hotspot_x);
				writer.write_int(hotspot_y);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn release_request(self: *const Pointer, writer: *Writer) void {
				const opcode = 1;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const Keyboard = struct {
			id: Id,
			keymap_callback: *const fn(*T, *Keyboard, Uint, Fd, Uint) void,
			enter_callback: *const fn(*T, *Keyboard, Uint, Object, Array) void,
			leave_callback: *const fn(*T, *Keyboard, Uint, Object) void,
			key_callback: *const fn(*T, *Keyboard, Uint, Uint, Uint, Uint) void,
			modifiers_callback: *const fn(*T, *Keyboard, Uint, Uint, Uint, Uint, Uint) void,
			repeat_info_callback: *const fn(*T, *Keyboard, Int, Int) void,
			pub const interface_name = "wl_keyboard";
			pub const interface_version = "10";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				switch (opcode) {
					0 => keymap_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					1 => enter_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					2 => leave_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					3 => key_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					4 => modifiers_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					5 => repeat_info_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					 else => @panic("Unknown opcode"),
				}
			}
			pub const KeymapFormat = enum(Uint) {
				@"no_keymap" = 0,
				@"xkb_v1" = 1,
			};
			pub const KeyState = enum(Uint) {
				@"released" = 0,
				@"pressed" = 1,
				@"repeated" = 2,
			};
			pub fn keymap_event(self: *Keyboard, ptr: *T, reader: *Reader) void {
				const format = reader.read_uint();
				const fd = reader.read_fd();
				const size = reader.read_uint();
				self.keymap_callback(ptr, self, format, fd, size);
			}
			pub fn enter_event(self: *Keyboard, ptr: *T, reader: *Reader) void {
				const serial = reader.read_uint();
				const surface = reader.read_object();
				const keys = reader.read_array();
				self.enter_callback(ptr, self, serial, surface, keys);
			}
			pub fn leave_event(self: *Keyboard, ptr: *T, reader: *Reader) void {
				const serial = reader.read_uint();
				const surface = reader.read_object();
				self.leave_callback(ptr, self, serial, surface);
			}
			pub fn key_event(self: *Keyboard, ptr: *T, reader: *Reader) void {
				const serial = reader.read_uint();
				const time = reader.read_uint();
				const key = reader.read_uint();
				const state = reader.read_uint();
				self.key_callback(ptr, self, serial, time, key, state);
			}
			pub fn modifiers_event(self: *Keyboard, ptr: *T, reader: *Reader) void {
				const serial = reader.read_uint();
				const mods_depressed = reader.read_uint();
				const mods_latched = reader.read_uint();
				const mods_locked = reader.read_uint();
				const group = reader.read_uint();
				self.modifiers_callback(ptr, self, serial, mods_depressed, mods_latched, mods_locked, group);
			}
			pub fn repeat_info_event(self: *Keyboard, ptr: *T, reader: *Reader) void {
				const rate = reader.read_int();
				const delay = reader.read_int();
				self.repeat_info_callback(ptr, self, rate, delay);
			}
			pub fn release_request(self: *const Keyboard, writer: *Writer) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const Touch = struct {
			id: Id,
			down_callback: *const fn(*T, *Touch, Uint, Uint, Object, Int, Fixed, Fixed) void,
			up_callback: *const fn(*T, *Touch, Uint, Uint, Int) void,
			motion_callback: *const fn(*T, *Touch, Uint, Int, Fixed, Fixed) void,
			frame_callback: *const fn(*T, *Touch) void,
			cancel_callback: *const fn(*T, *Touch) void,
			shape_callback: *const fn(*T, *Touch, Int, Fixed, Fixed) void,
			orientation_callback: *const fn(*T, *Touch, Int, Fixed) void,
			pub const interface_name = "wl_touch";
			pub const interface_version = "10";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				switch (opcode) {
					0 => down_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					1 => up_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					2 => motion_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					3 => frame_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					4 => cancel_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					5 => shape_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					6 => orientation_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					 else => @panic("Unknown opcode"),
				}
			}
			pub fn down_event(self: *Touch, ptr: *T, reader: *Reader) void {
				const serial = reader.read_uint();
				const time = reader.read_uint();
				const surface = reader.read_object();
				const id = reader.read_int();
				const x = reader.read_fixed();
				const y = reader.read_fixed();
				self.down_callback(ptr, self, serial, time, surface, id, x, y);
			}
			pub fn up_event(self: *Touch, ptr: *T, reader: *Reader) void {
				const serial = reader.read_uint();
				const time = reader.read_uint();
				const id = reader.read_int();
				self.up_callback(ptr, self, serial, time, id);
			}
			pub fn motion_event(self: *Touch, ptr: *T, reader: *Reader) void {
				const time = reader.read_uint();
				const id = reader.read_int();
				const x = reader.read_fixed();
				const y = reader.read_fixed();
				self.motion_callback(ptr, self, time, id, x, y);
			}
			pub fn frame_event(self: *Touch, ptr: *T, reader: *Reader) void {
			_ = reader;
				self.frame_callback(ptr, self);
			}
			pub fn cancel_event(self: *Touch, ptr: *T, reader: *Reader) void {
			_ = reader;
				self.cancel_callback(ptr, self);
			}
			pub fn shape_event(self: *Touch, ptr: *T, reader: *Reader) void {
				const id = reader.read_int();
				const major = reader.read_fixed();
				const minor = reader.read_fixed();
				self.shape_callback(ptr, self, id, major, minor);
			}
			pub fn orientation_event(self: *Touch, ptr: *T, reader: *Reader) void {
				const id = reader.read_int();
				const orientation = reader.read_fixed();
				self.orientation_callback(ptr, self, id, orientation);
			}
			pub fn release_request(self: *const Touch, writer: *Writer) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const Output = struct {
			id: Id,
			geometry_callback: *const fn(*T, *Output, Int, Int, Int, Int, Int, String, String, Int) void,
			mode_callback: *const fn(*T, *Output, Uint, Int, Int, Int) void,
			done_callback: *const fn(*T, *Output) void,
			scale_callback: *const fn(*T, *Output, Int) void,
			name_callback: *const fn(*T, *Output, String) void,
			description_callback: *const fn(*T, *Output, String) void,
			pub const interface_name = "wl_output";
			pub const interface_version = "4";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				switch (opcode) {
					0 => geometry_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					1 => mode_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					2 => done_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					3 => scale_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					4 => name_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					5 => description_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					 else => @panic("Unknown opcode"),
				}
			}
			pub const Subpixel = enum(Uint) {
				@"unknown" = 0,
				@"none" = 1,
				@"horizontal_rgb" = 2,
				@"horizontal_bgr" = 3,
				@"vertical_rgb" = 4,
				@"vertical_bgr" = 5,
			};
			pub const Transform = enum(Uint) {
				@"normal" = 0,
				@"90" = 1,
				@"180" = 2,
				@"270" = 3,
				@"flipped" = 4,
				@"flipped_90" = 5,
				@"flipped_180" = 6,
				@"flipped_270" = 7,
			};
			pub const Mode = enum(Uint) {
				@"current" = 0x1,
				@"preferred" = 0x2,
			};
			pub fn geometry_event(self: *Output, ptr: *T, reader: *Reader) void {
				const x = reader.read_int();
				const y = reader.read_int();
				const physical_width = reader.read_int();
				const physical_height = reader.read_int();
				const subpixel = reader.read_int();
				const make = reader.read_string();
				const model = reader.read_string();
				const transform = reader.read_int();
				self.geometry_callback(ptr, self, x, y, physical_width, physical_height, subpixel, make, model, transform);
			}
			pub fn mode_event(self: *Output, ptr: *T, reader: *Reader) void {
				const flags = reader.read_uint();
				const width = reader.read_int();
				const height = reader.read_int();
				const refresh = reader.read_int();
				self.mode_callback(ptr, self, flags, width, height, refresh);
			}
			pub fn done_event(self: *Output, ptr: *T, reader: *Reader) void {
			_ = reader;
				self.done_callback(ptr, self);
			}
			pub fn scale_event(self: *Output, ptr: *T, reader: *Reader) void {
				const factor = reader.read_int();
				self.scale_callback(ptr, self, factor);
			}
			pub fn name_event(self: *Output, ptr: *T, reader: *Reader) void {
				const name = reader.read_string();
				self.name_callback(ptr, self, name);
			}
			pub fn description_event(self: *Output, ptr: *T, reader: *Reader) void {
				const description = reader.read_string();
				self.description_callback(ptr, self, description);
			}
			pub fn release_request(self: *const Output, writer: *Writer) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const Region = struct {
			id: Id,
			pub const interface_name = "wl_region";
			pub const interface_version = "1";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				_ = self_ptr;
				_ = ptr;
				switch (opcode) {
					 else => @panic("Unknown opcode"),
				}
			}
			pub fn destroy_request(self: *const Region, writer: *Writer) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn add_request(self: *const Region, writer: *Writer, x: Int, y: Int, width: Int, height: Int) void {
				const opcode = 1;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_int(x);
				writer.write_int(y);
				writer.write_int(width);
				writer.write_int(height);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn subtract_request(self: *const Region, writer: *Writer, x: Int, y: Int, width: Int, height: Int) void {
				const opcode = 2;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_int(x);
				writer.write_int(y);
				writer.write_int(width);
				writer.write_int(height);
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const Subcompositor = struct {
			id: Id,
			pub const interface_name = "wl_subcompositor";
			pub const interface_version = "1";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				_ = self_ptr;
				_ = ptr;
				switch (opcode) {
					 else => @panic("Unknown opcode"),
				}
			}
			pub const Error = enum(Uint) {
				@"bad_surface" = 0,
				@"bad_parent" = 1,
			};
			pub fn destroy_request(self: *const Subcompositor, writer: *Writer) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn get_subsurface_request(self: *const Subcompositor, writer: *Writer, id: NewId, surface: Object, parent: Object) void {
				const opcode = 1;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_new_id(id);
				writer.write_object(surface);
				writer.write_object(parent);
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const Subsurface = struct {
			id: Id,
			pub const interface_name = "wl_subsurface";
			pub const interface_version = "1";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				_ = self_ptr;
				_ = ptr;
				switch (opcode) {
					 else => @panic("Unknown opcode"),
				}
			}
			pub const Error = enum(Uint) {
				@"bad_surface" = 0,
			};
			pub fn destroy_request(self: *const Subsurface, writer: *Writer) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_position_request(self: *const Subsurface, writer: *Writer, x: Int, y: Int) void {
				const opcode = 1;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_int(x);
				writer.write_int(y);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn place_above_request(self: *const Subsurface, writer: *Writer, sibling: Object) void {
				const opcode = 2;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_object(sibling);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn place_below_request(self: *const Subsurface, writer: *Writer, sibling: Object) void {
				const opcode = 3;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_object(sibling);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_sync_request(self: *const Subsurface, writer: *Writer) void {
				const opcode = 4;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_desync_request(self: *const Subsurface, writer: *Writer) void {
				const opcode = 5;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const Fixes = struct {
			id: Id,
			pub const interface_name = "wl_fixes";
			pub const interface_version = "1";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				_ = self_ptr;
				_ = ptr;
				switch (opcode) {
					 else => @panic("Unknown opcode"),
				}
			}
			pub fn destroy_request(self: *const Fixes, writer: *Writer) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn destroy_registry_request(self: *const Fixes, writer: *Writer, registry: Object) void {
				const opcode = 1;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_object(registry);
				message_size.* = @intCast(writer.offset - off);
			}
		};
	};
}
pub fn Xdg(T: type) type {
	return struct {
		pub const WmBase = struct {
			id: Id,
			ping_callback: *const fn(*T, *WmBase, Uint) void,
			pub const interface_name = "xdg_wm_base";
			pub const interface_version = "7";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				switch (opcode) {
					0 => ping_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					 else => @panic("Unknown opcode"),
				}
			}
			pub const Error = enum(Uint) {
				@"role" = 0,
				@"defunct_surfaces" = 1,
				@"not_the_topmost_popup" = 2,
				@"invalid_popup_parent" = 3,
				@"invalid_surface_state" = 4,
				@"invalid_positioner" = 5,
				@"unresponsive" = 6,
			};
			pub fn ping_event(self: *WmBase, ptr: *T, reader: *Reader) void {
				const serial = reader.read_uint();
				self.ping_callback(ptr, self, serial);
			}
			pub fn destroy_request(self: *const WmBase, writer: *Writer) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn create_positioner_request(self: *const WmBase, writer: *Writer, id: NewId) void {
				const opcode = 1;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_new_id(id);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn get_xdg_surface_request(self: *const WmBase, writer: *Writer, id: NewId, surface: Object) void {
				const opcode = 2;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_new_id(id);
				writer.write_object(surface);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn pong_request(self: *const WmBase, writer: *Writer, serial: Uint) void {
				const opcode = 3;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_uint(serial);
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const Positioner = struct {
			id: Id,
			pub const interface_name = "xdg_positioner";
			pub const interface_version = "7";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				_ = self_ptr;
				_ = ptr;
				switch (opcode) {
					 else => @panic("Unknown opcode"),
				}
			}
			pub const Error = enum(Uint) {
				@"invalid_input" = 0,
			};
			pub const Anchor = enum(Uint) {
				@"none" = 0,
				@"top" = 1,
				@"bottom" = 2,
				@"left" = 3,
				@"right" = 4,
				@"top_left" = 5,
				@"bottom_left" = 6,
				@"top_right" = 7,
				@"bottom_right" = 8,
			};
			pub const Gravity = enum(Uint) {
				@"none" = 0,
				@"top" = 1,
				@"bottom" = 2,
				@"left" = 3,
				@"right" = 4,
				@"top_left" = 5,
				@"bottom_left" = 6,
				@"top_right" = 7,
				@"bottom_right" = 8,
			};
			pub const ConstraintAdjustment = enum(Uint) {
				@"none" = 0,
				@"slide_x" = 1,
				@"slide_y" = 2,
				@"flip_x" = 4,
				@"flip_y" = 8,
				@"resize_x" = 16,
				@"resize_y" = 32,
			};
			pub fn destroy_request(self: *const Positioner, writer: *Writer) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_size_request(self: *const Positioner, writer: *Writer, width: Int, height: Int) void {
				const opcode = 1;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_int(width);
				writer.write_int(height);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_anchor_rect_request(self: *const Positioner, writer: *Writer, x: Int, y: Int, width: Int, height: Int) void {
				const opcode = 2;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_int(x);
				writer.write_int(y);
				writer.write_int(width);
				writer.write_int(height);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_anchor_request(self: *const Positioner, writer: *Writer, anchor: Uint) void {
				const opcode = 3;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_uint(anchor);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_gravity_request(self: *const Positioner, writer: *Writer, gravity: Uint) void {
				const opcode = 4;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_uint(gravity);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_constraint_adjustment_request(self: *const Positioner, writer: *Writer, constraint_adjustment: Uint) void {
				const opcode = 5;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_uint(constraint_adjustment);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_offset_request(self: *const Positioner, writer: *Writer, x: Int, y: Int) void {
				const opcode = 6;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_int(x);
				writer.write_int(y);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_reactive_request(self: *const Positioner, writer: *Writer) void {
				const opcode = 7;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_parent_size_request(self: *const Positioner, writer: *Writer, parent_width: Int, parent_height: Int) void {
				const opcode = 8;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_int(parent_width);
				writer.write_int(parent_height);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_parent_configure_request(self: *const Positioner, writer: *Writer, serial: Uint) void {
				const opcode = 9;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_uint(serial);
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const Surface = struct {
			id: Id,
			configure_callback: *const fn(*T, *Surface, Uint) void,
			pub const interface_name = "xdg_surface";
			pub const interface_version = "7";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				switch (opcode) {
					0 => configure_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					 else => @panic("Unknown opcode"),
				}
			}
			pub const Error = enum(Uint) {
				@"not_constructed" = 1,
				@"already_constructed" = 2,
				@"unconfigured_buffer" = 3,
				@"invalid_serial" = 4,
				@"invalid_size" = 5,
				@"defunct_role_object" = 6,
			};
			pub fn configure_event(self: *Surface, ptr: *T, reader: *Reader) void {
				const serial = reader.read_uint();
				self.configure_callback(ptr, self, serial);
			}
			pub fn destroy_request(self: *const Surface, writer: *Writer) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn get_toplevel_request(self: *const Surface, writer: *Writer, id: NewId) void {
				const opcode = 1;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_new_id(id);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn get_popup_request(self: *const Surface, writer: *Writer, id: NewId, parent: Object, positioner: Object) void {
				const opcode = 2;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_new_id(id);
				writer.write_object(parent);
				writer.write_object(positioner);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_window_geometry_request(self: *const Surface, writer: *Writer, x: Int, y: Int, width: Int, height: Int) void {
				const opcode = 3;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_int(x);
				writer.write_int(y);
				writer.write_int(width);
				writer.write_int(height);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn ack_configure_request(self: *const Surface, writer: *Writer, serial: Uint) void {
				const opcode = 4;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_uint(serial);
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const Toplevel = struct {
			id: Id,
			configure_callback: *const fn(*T, *Toplevel, Int, Int, Array) void,
			close_callback: *const fn(*T, *Toplevel) void,
			configure_bounds_callback: *const fn(*T, *Toplevel, Int, Int) void,
			wm_capabilities_callback: *const fn(*T, *Toplevel, Array) void,
			pub const interface_name = "xdg_toplevel";
			pub const interface_version = "7";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				switch (opcode) {
					0 => configure_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					1 => close_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					2 => configure_bounds_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					3 => wm_capabilities_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					 else => @panic("Unknown opcode"),
				}
			}
			pub const Error = enum(Uint) {
				@"invalid_resize_edge" = 0,
				@"invalid_parent" = 1,
				@"invalid_size" = 2,
			};
			pub const ResizeEdge = enum(Uint) {
				@"none" = 0,
				@"top" = 1,
				@"bottom" = 2,
				@"left" = 4,
				@"top_left" = 5,
				@"bottom_left" = 6,
				@"right" = 8,
				@"top_right" = 9,
				@"bottom_right" = 10,
			};
			pub const State = enum(Uint) {
				@"maximized" = 1,
				@"fullscreen" = 2,
				@"resizing" = 3,
				@"activated" = 4,
				@"tiled_left" = 5,
				@"tiled_right" = 6,
				@"tiled_top" = 7,
				@"tiled_bottom" = 8,
				@"suspended" = 9,
				@"constrained_left" = 10,
				@"constrained_right" = 11,
				@"constrained_top" = 12,
				@"constrained_bottom" = 13,
			};
			pub const WmCapabilities = enum(Uint) {
				@"window_menu" = 1,
				@"maximize" = 2,
				@"fullscreen" = 3,
				@"minimize" = 4,
			};
			pub fn configure_event(self: *Toplevel, ptr: *T, reader: *Reader) void {
				const width = reader.read_int();
				const height = reader.read_int();
				const states = reader.read_array();
				self.configure_callback(ptr, self, width, height, states);
			}
			pub fn close_event(self: *Toplevel, ptr: *T, reader: *Reader) void {
			_ = reader;
				self.close_callback(ptr, self);
			}
			pub fn configure_bounds_event(self: *Toplevel, ptr: *T, reader: *Reader) void {
				const width = reader.read_int();
				const height = reader.read_int();
				self.configure_bounds_callback(ptr, self, width, height);
			}
			pub fn wm_capabilities_event(self: *Toplevel, ptr: *T, reader: *Reader) void {
				const capabilities = reader.read_array();
				self.wm_capabilities_callback(ptr, self, capabilities);
			}
			pub fn destroy_request(self: *const Toplevel, writer: *Writer) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_parent_request(self: *const Toplevel, writer: *Writer, parent: Object) void {
				const opcode = 1;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_object(parent);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_title_request(self: *const Toplevel, writer: *Writer, title: String) void {
				const opcode = 2;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_string(title);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_app_id_request(self: *const Toplevel, writer: *Writer, app_id: String) void {
				const opcode = 3;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_string(app_id);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn show_window_menu_request(self: *const Toplevel, writer: *Writer, seat: Object, serial: Uint, x: Int, y: Int) void {
				const opcode = 4;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_object(seat);
				writer.write_uint(serial);
				writer.write_int(x);
				writer.write_int(y);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn move_request(self: *const Toplevel, writer: *Writer, seat: Object, serial: Uint) void {
				const opcode = 5;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_object(seat);
				writer.write_uint(serial);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn resize_request(self: *const Toplevel, writer: *Writer, seat: Object, serial: Uint, edges: Uint) void {
				const opcode = 6;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_object(seat);
				writer.write_uint(serial);
				writer.write_uint(edges);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_max_size_request(self: *const Toplevel, writer: *Writer, width: Int, height: Int) void {
				const opcode = 7;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_int(width);
				writer.write_int(height);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_min_size_request(self: *const Toplevel, writer: *Writer, width: Int, height: Int) void {
				const opcode = 8;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_int(width);
				writer.write_int(height);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_maximized_request(self: *const Toplevel, writer: *Writer) void {
				const opcode = 9;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn unset_maximized_request(self: *const Toplevel, writer: *Writer) void {
				const opcode = 10;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_fullscreen_request(self: *const Toplevel, writer: *Writer, output: Object) void {
				const opcode = 11;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_object(output);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn unset_fullscreen_request(self: *const Toplevel, writer: *Writer) void {
				const opcode = 12;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn set_minimized_request(self: *const Toplevel, writer: *Writer) void {
				const opcode = 13;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const Popup = struct {
			id: Id,
			configure_callback: *const fn(*T, *Popup, Int, Int, Int, Int) void,
			popup_done_callback: *const fn(*T, *Popup) void,
			repositioned_callback: *const fn(*T, *Popup, Uint) void,
			pub const interface_name = "xdg_popup";
			pub const interface_version = "7";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				switch (opcode) {
					0 => configure_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					1 => popup_done_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					2 => repositioned_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					 else => @panic("Unknown opcode"),
				}
			}
			pub const Error = enum(Uint) {
				@"invalid_grab" = 0,
			};
			pub fn configure_event(self: *Popup, ptr: *T, reader: *Reader) void {
				const x = reader.read_int();
				const y = reader.read_int();
				const width = reader.read_int();
				const height = reader.read_int();
				self.configure_callback(ptr, self, x, y, width, height);
			}
			pub fn popup_done_event(self: *Popup, ptr: *T, reader: *Reader) void {
			_ = reader;
				self.popup_done_callback(ptr, self);
			}
			pub fn repositioned_event(self: *Popup, ptr: *T, reader: *Reader) void {
				const token = reader.read_uint();
				self.repositioned_callback(ptr, self, token);
			}
			pub fn destroy_request(self: *const Popup, writer: *Writer) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn grab_request(self: *const Popup, writer: *Writer, seat: Object, serial: Uint) void {
				const opcode = 1;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_object(seat);
				writer.write_uint(serial);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn reposition_request(self: *const Popup, writer: *Writer, positioner: Object, token: Uint) void {
				const opcode = 2;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_object(positioner);
				writer.write_uint(token);
				message_size.* = @intCast(writer.offset - off);
			}
		};
	};
}
pub fn Zwp(T: type) type {
	return struct {
		pub const LinuxDmabufV1 = struct {
			id: Id,
			format_callback: *const fn(*T, *LinuxDmabufV1, Uint) void,
			modifier_callback: *const fn(*T, *LinuxDmabufV1, Uint, Uint, Uint) void,
			pub const interface_name = "zwp_linux_dmabuf_v1";
			pub const interface_version = "5";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				switch (opcode) {
					0 => format_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					1 => modifier_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					 else => @panic("Unknown opcode"),
				}
			}
			pub fn format_event(self: *LinuxDmabufV1, ptr: *T, reader: *Reader) void {
				const format = reader.read_uint();
				self.format_callback(ptr, self, format);
			}
			pub fn modifier_event(self: *LinuxDmabufV1, ptr: *T, reader: *Reader) void {
				const format = reader.read_uint();
				const modifier_hi = reader.read_uint();
				const modifier_lo = reader.read_uint();
				self.modifier_callback(ptr, self, format, modifier_hi, modifier_lo);
			}
			pub fn destroy_request(self: *const LinuxDmabufV1, writer: *Writer) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn create_params_request(self: *const LinuxDmabufV1, writer: *Writer, params_id: NewId) void {
				const opcode = 1;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_new_id(params_id);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn get_default_feedback_request(self: *const LinuxDmabufV1, writer: *Writer, id: NewId) void {
				const opcode = 2;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_new_id(id);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn get_surface_feedback_request(self: *const LinuxDmabufV1, writer: *Writer, id: NewId, surface: Object) void {
				const opcode = 3;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_new_id(id);
				writer.write_object(surface);
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const LinuxBufferParamsV1 = struct {
			id: Id,
			created_callback: *const fn(*T, *LinuxBufferParamsV1, NewId) void,
			failed_callback: *const fn(*T, *LinuxBufferParamsV1) void,
			pub const interface_name = "zwp_linux_buffer_params_v1";
			pub const interface_version = "5";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				switch (opcode) {
					0 => created_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					1 => failed_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					 else => @panic("Unknown opcode"),
				}
			}
			pub const Error = enum(Uint) {
				@"already_used" = 0,
				@"plane_idx" = 1,
				@"plane_set" = 2,
				@"incomplete" = 3,
				@"invalid_format" = 4,
				@"invalid_dimensions" = 5,
				@"out_of_bounds" = 6,
				@"invalid_wl_buffer" = 7,
			};
			pub const Flags = enum(Uint) {
				@"y_invert" = 1,
				@"interlaced" = 2,
				@"bottom_first" = 4,
			};
			pub fn created_event(self: *LinuxBufferParamsV1, ptr: *T, reader: *Reader) void {
				const buffer = reader.read_new_id();
				self.created_callback(ptr, self, buffer);
			}
			pub fn failed_event(self: *LinuxBufferParamsV1, ptr: *T, reader: *Reader) void {
			_ = reader;
				self.failed_callback(ptr, self);
			}
			pub fn destroy_request(self: *const LinuxBufferParamsV1, writer: *Writer) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn add_request(self: *const LinuxBufferParamsV1, writer: *Writer, fd: Fd, plane_idx: Uint, offset: Uint, stride: Uint, modifier_hi: Uint, modifier_lo: Uint) void {
				const opcode = 1;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_fd(fd);
				writer.write_uint(plane_idx);
				writer.write_uint(offset);
				writer.write_uint(stride);
				writer.write_uint(modifier_hi);
				writer.write_uint(modifier_lo);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn create_request(self: *const LinuxBufferParamsV1, writer: *Writer, width: Int, height: Int, format: Uint, flags: Uint) void {
				const opcode = 2;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_int(width);
				writer.write_int(height);
				writer.write_uint(format);
				writer.write_uint(flags);
				message_size.* = @intCast(writer.offset - off);
			}
			pub fn create_immed_request(self: *const LinuxBufferParamsV1, writer: *Writer, buffer_id: NewId, width: Int, height: Int, format: Uint, flags: Uint) void {
				const opcode = 3;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				writer.write_new_id(buffer_id);
				writer.write_int(width);
				writer.write_int(height);
				writer.write_uint(format);
				writer.write_uint(flags);
				message_size.* = @intCast(writer.offset - off);
			}
		};
		pub const LinuxDmabufFeedbackV1 = struct {
			id: Id,
			done_callback: *const fn(*T, *LinuxDmabufFeedbackV1) void,
			format_table_callback: *const fn(*T, *LinuxDmabufFeedbackV1, Fd, Uint) void,
			main_device_callback: *const fn(*T, *LinuxDmabufFeedbackV1, Array) void,
			tranche_done_callback: *const fn(*T, *LinuxDmabufFeedbackV1) void,
			tranche_target_device_callback: *const fn(*T, *LinuxDmabufFeedbackV1, Array) void,
			tranche_formats_callback: *const fn(*T, *LinuxDmabufFeedbackV1, Array) void,
			tranche_flags_callback: *const fn(*T, *LinuxDmabufFeedbackV1, Uint) void,
			pub const interface_name = "zwp_linux_dmabuf_feedback_v1";
			pub const interface_version = "5";
			pub fn event(self_ptr: *anyopaque, ptr: *T, reader: *Reader) void {
				const opcode = reader.read_opcode();
				const size = reader.read_message_size();
				_ = size;
				switch (opcode) {
					0 => done_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					1 => format_table_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					2 => main_device_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					3 => tranche_done_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					4 => tranche_target_device_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					5 => tranche_formats_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					6 => tranche_flags_event(@ptrCast(@alignCast(self_ptr)), ptr, reader),
					 else => @panic("Unknown opcode"),
				}
			}
			pub const TrancheFlags = enum(Uint) {
				@"scanout" = 1,
			};
			pub fn done_event(self: *LinuxDmabufFeedbackV1, ptr: *T, reader: *Reader) void {
			_ = reader;
				self.done_callback(ptr, self);
			}
			pub fn format_table_event(self: *LinuxDmabufFeedbackV1, ptr: *T, reader: *Reader) void {
				const fd = reader.read_fd();
				const size = reader.read_uint();
				self.format_table_callback(ptr, self, fd, size);
			}
			pub fn main_device_event(self: *LinuxDmabufFeedbackV1, ptr: *T, reader: *Reader) void {
				const device = reader.read_array();
				self.main_device_callback(ptr, self, device);
			}
			pub fn tranche_done_event(self: *LinuxDmabufFeedbackV1, ptr: *T, reader: *Reader) void {
			_ = reader;
				self.tranche_done_callback(ptr, self);
			}
			pub fn tranche_target_device_event(self: *LinuxDmabufFeedbackV1, ptr: *T, reader: *Reader) void {
				const device = reader.read_array();
				self.tranche_target_device_callback(ptr, self, device);
			}
			pub fn tranche_formats_event(self: *LinuxDmabufFeedbackV1, ptr: *T, reader: *Reader) void {
				const indices = reader.read_array();
				self.tranche_formats_callback(ptr, self, indices);
			}
			pub fn tranche_flags_event(self: *LinuxDmabufFeedbackV1, ptr: *T, reader: *Reader) void {
				const flags = reader.read_uint();
				self.tranche_flags_callback(ptr, self, flags);
			}
			pub fn destroy_request(self: *const LinuxDmabufFeedbackV1, writer: *Writer) void {
				const opcode = 0;
				const off = writer.offset;
				writer.write_id(self.id);
				writer.write_opcode(opcode);
				const message_size = writer.reserve_message_size();
				message_size.* = @intCast(writer.offset - off);
			}
		};
	};
}
