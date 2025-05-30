package wayland

import "base:intrinsics"
import "base:runtime"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:sys/posix"
import "core:math/linalg"
import "core:math"
import "core:log"
import "core:fmt"
import "core:time"

import "lib:vulkan"
import "lib:collection/vector"
import "lib:xkb"
import "lib:error"
import "lib:wayland/interface"

@private
InterfaceObject :: struct {
  interface: ^interface.Interface,
  callbacks: vector.Vector(Callback),
}

@private
Modifier :: struct {
  format:   u32,
  modifier: u64,
}

@private Listen :: proc(ptr: rawptr, keymap: ^xkb.Keymap_Context, time: i64) -> error.Error

@private
KeyListener :: struct {
  ptr: rawptr,
  f: Listen,
}

@private
Ids :: struct {
  display: u32,
  registry: u32,
  compositor: u32,
  surface: u32,
  seat: u32,
  keyboard: u32,
  pointer: u32,
  xdg_wm_base: u32,
  xdg_surface: u32,
  xdg_toplevel: u32,
  dma: u32,
  dma_feedback: u32,
  dma_params: u32,
  buffer_base: u32,
}

@private
Opcodes :: struct {
  get_registry: u32,
  registry_bind: u32,
  create_surface: u32,
  surface_attach: u32,
  surface_commit: u32,
  surface_damage: u32,
  ack_configure:  u32,
  get_pointer: u32,
  get_keyboard: u32,
  get_xdg_surface: u32,
  get_toplevel: u32,
  pong: u32,
  destroy_buffer: u32,
  dma_destroy: u32,
  dma_create_param: u32,
  dma_surface_feedback: u32,
  dma_feedback_destroy: u32,
  dma_params_create_immed: u32,
  dma_params_add: u32,
  dma_params_destroy: u32,
}

Wayland_Context :: struct {
  socket: posix.FD,

  objects: vector.Vector(InterfaceObject),

  modifiers: vector.Vector(Modifier),
  dma_main_device: u64,

  output: vector.Buffer,
  input: vector.Buffer,
  in_fds: vector.Buffer,
  out_fds: vector.Vector(interface.Fd),
  values: vector.Vector(interface.Argument),
  bytes: []u8,

  buffers: vector.Vector(Buffer),
  active_buffer: u32,

  ids: Ids,
  opcodes: Opcodes,

  width: u32,
  height: u32,

  listeners: vector.Vector(KeyListener),
  keymap: xkb.Keymap_Context,

  key_delay: i64,
  key_repeat: i64,

  key_start: i64,
  key_last_time: i64,

  vk: ^vulkan.Vulkan_Context,

  arena: ^mem.Arena,
  allocator: runtime.Allocator,
  tmp_arena: ^mem.Arena,
  tmp_allocator: runtime.Allocator,

  running: bool,
}

wayland_init :: proc(ctx: ^Wayland_Context, vk: ^vulkan.Vulkan_Context, width: u32, height: u32, frame_count: u32, arena: ^mem.Arena, tmp_arena: ^mem.Arena) -> error.Error {
  log.info("Initializing Wayland")

  mark := mem.begin_arena_temp_memory(tmp_arena)
  defer mem.end_arena_temp_memory(mark)

  ctx.arena = arena
  ctx.allocator = mem.arena_allocator(arena)
  ctx.tmp_arena = tmp_arena
  ctx.tmp_allocator = mem.arena_allocator(tmp_arena)

  ctx.vk = vk

  xdg_path := os.get_env("XDG_RUNTIME_DIR", allocator = ctx.tmp_allocator)
  wayland_path := os.get_env("WAYLAND_DISPLAY", allocator = ctx.tmp_allocator)

  if len(xdg_path) == 0 || len(wayland_path) == 0 {
    return .EnviromentVariablesNotSet
  }

  path := filepath.join({xdg_path, wayland_path}, ctx.tmp_allocator)
  ctx.socket = posix.socket(.UNIX, .STREAM)

  if ctx.socket < 0 {
    return .WaylandSocketNotAvaiable
  }

  sockaddr := posix.sockaddr_un {
    sun_family = .UNIX,
  }

  count: uint = 0
  for c in path {
    sockaddr.sun_path[count] = u8(c)
    count += 1
  }

  if posix.connect(ctx.socket, (^posix.sockaddr)(&sockaddr), posix.socklen_t(size_of(posix.sockaddr_un))) == .FAIL do return .SocketConnectFailed

  resize(ctx, width, height) or_return

  ctx.values = vector.new(interface.Argument, 40, ctx.allocator) or_return
  ctx.objects = vector.new(InterfaceObject, 40, ctx.allocator) or_return
  ctx.output = vector.buffer_new(4096, ctx.allocator) or_return
  ctx.input = vector.buffer_new(4096, ctx.allocator) or_return
  ctx.modifiers = vector.new(Modifier, 512, ctx.allocator) or_return
  ctx.listeners = vector.new(KeyListener, 10, ctx.allocator) or_return
  ctx.bytes = make([]u8, 1024, ctx.allocator)

  ctx.out_fds = vector.new(interface.Fd, 100, ctx.allocator) or_return
  ctx.in_fds = vector.buffer_new(100, ctx.allocator) or_return

  ctx.key_delay = 200 * 1000 * 1000
  ctx.key_repeat = 30 * 1000 * 1000

  ctx.buffers = vector.new(Buffer, frame_count, ctx.allocator) or_return
  ctx.active_buffer = 0

  ctx.ids.display = get_id(ctx, "wl_display", {new_callback("error", error_callback), new_callback("delete_id", delete_callback)}, interface.WAYLAND_INTERFACES[:]) or_return
  ctx.ids.registry = get_id(ctx, "wl_registry", { new_callback("global", global_callback), new_callback("global_remove", global_remove_callback), }, interface.WAYLAND_INTERFACES[:]) or_return
  ctx.opcodes.get_registry = get_request_opcode(ctx, "get_registry", ctx.ids.display) or_return

  write(ctx, {interface.BoundNewId(ctx.ids.registry)}, ctx.ids.display, ctx.opcodes.get_registry) or_return
  send(ctx) or_return

  roundtrip(ctx) or_return
  send(ctx) or_return
  roundtrip(ctx) or_return

  dma_params_init(ctx) or_return

  buffers_init(ctx) or_return
  buffer_write_swap(ctx, ctx.width, ctx.height) or_return
  send(ctx) or_return

  ctx.running = true

  return nil
}

render :: proc(ctx: ^Wayland_Context) -> error.Error {
  time.sleep(time.Millisecond * 30)

  roundtrip(ctx) or_return
  handle_input(ctx) or_return

  buffer_write_swap(ctx, ctx.width, ctx.height) or_return

  send(ctx) or_return

  return nil
}

@private
handle_input :: proc(ctx: ^Wayland_Context) -> error.Error {
  now := time.now()._nsec

  if ctx.keymap.pressed_array.len == 0 do return nil

  if now >= ctx.key_start + ctx.key_delay {
    if now >= ctx.key_last_time + ctx.key_repeat {
      send_input(ctx, now) or_return
    }
  }

  return nil
}

@private
send_input :: proc(ctx: ^Wayland_Context, now: i64) -> error.Error {
  for i in 0..<ctx.listeners.len {
    listener := &ctx.listeners.data[i]
    listener.f(listener.ptr, &ctx.keymap, now) or_return
  }

  ctx.key_last_time = now

  return nil
}

add_listener :: proc(ctx: ^Wayland_Context, ptr: rawptr, f: Listen) -> error.Error {
  vector.append(&ctx.listeners, KeyListener { ptr = ptr, f = f}) or_return

  return nil
}

wayland_deinit :: proc(ctx: ^Wayland_Context) {}

@private
resize :: proc(ctx: ^Wayland_Context, width: u32, height: u32) -> error.Error {
  ctx.width = width
  ctx.height = height

  far := f32(10)
  near := f32(1)

  fovy := f32(3.14 / 4)
  tan_fovy := math.tan(0.5 * fovy)

  f_width := f32(width)
  f_height := f32(height)
  aspect := f32(width) / f32(height)

  scale := matrix[4, 4]f32{
    1 / (aspect * tan_fovy), 0, 0, 0, 
    0, -1 / (tan_fovy), 0, 0, 
    0, 0, 1 / (far - near), 0, 
    0, 0, 0, 1, 
  }

  translate := matrix[4, 4]f32{
    1, 0, 0, 0, 
    0, 1, 0, 0, 
    0, 0, -1, -near / (far - near), 
    0, 0, -1, 0, 
  }

  projection := scale * translate

  vulkan.update_projection(ctx.vk, projection) or_return

  return nil
}

@private
roundtrip :: proc(ctx: ^Wayland_Context) -> error.Error {
  recv(ctx) or_return
  for read(ctx) == nil {}

  return nil
}

@private
surface_create :: proc(ctx: ^Wayland_Context) -> error.Error {
  ctx.ids.surface = get_id(ctx, "wl_surface", { new_callback("enter", enter_callback), new_callback("leave", leave_callback), new_callback("preferred_buffer_scale", preferred_buffer_scale_callback), new_callback("preferred_buffer_transform", preferred_buffer_transform_callback), }, interface.WAYLAND_INTERFACES[:]) or_return
  ctx.opcodes.surface_attach = get_request_opcode(ctx, "attach", ctx.ids.surface) or_return
  ctx.opcodes.surface_commit = get_request_opcode(ctx, "commit", ctx.ids.surface) or_return
  ctx.opcodes.surface_damage = get_request_opcode(ctx, "damage", ctx.ids.surface) or_return

  write(ctx, {interface.BoundNewId(ctx.ids.surface)}, ctx.ids.compositor, ctx.opcodes.create_surface) or_return
  dma_create(ctx) or_return

  return nil
}

@private
xdg_surface_create :: proc(ctx: ^Wayland_Context) -> error.Error {
  ctx.ids.xdg_surface = get_id(ctx, "xdg_surface", {new_callback("configure", configure_callback)}, interface.XDG_INTERFACES[:]) or_return
  ctx.opcodes.get_toplevel = get_request_opcode(ctx, "get_toplevel", ctx.ids.xdg_surface) or_return
  ctx.opcodes.ack_configure = get_request_opcode(ctx, "ack_configure", ctx.ids.xdg_surface) or_return

  ctx.ids.xdg_toplevel = get_id(ctx, "xdg_toplevel", { new_callback("configure", toplevel_configure_callback), new_callback("close", toplevel_close_callback), new_callback("configure_bounds", toplevel_configure_bounds_callback), new_callback("wm_capabilities", toplevel_wm_capabilities_callback), }, interface.XDG_INTERFACES[:]) or_return

  write(ctx, {interface.BoundNewId(ctx.ids.xdg_surface), interface.Object(ctx.ids.surface)}, ctx.ids.xdg_wm_base, ctx.opcodes.get_xdg_surface) or_return
  write(ctx, {interface.BoundNewId(ctx.ids.xdg_toplevel)}, ctx.ids.xdg_surface, ctx.opcodes.get_toplevel) or_return
  write(ctx, {}, ctx.ids.surface, ctx.opcodes.surface_commit) or_return

  return nil
}

@(private = "file")
dma_create :: proc(ctx: ^Wayland_Context) -> error.Error {
  ctx.ids.dma_feedback = get_id(ctx, "zwp_linux_dmabuf_feedback_v1", { new_callback("done", dma_done_callback), new_callback("format_table", dma_format_table_callback), new_callback("main_device", dma_main_device_callback), new_callback("tranche_done", dma_tranche_done_callback), new_callback("tranche_target_device", dma_tranche_target_device_callback), new_callback("tranche_formats", dma_tranche_formats_callback), new_callback("tranche_flags", dma_tranche_flags_callback), }, interface.DMA_INTERFACES[:]) or_return
  ctx.opcodes.dma_feedback_destroy = get_request_opcode(ctx, "destroy", ctx.ids.dma_feedback) or_return

  write(ctx, {interface.BoundNewId(ctx.ids.dma_feedback), interface.Object(ctx.ids.surface)}, ctx.ids.dma, ctx.opcodes.dma_surface_feedback) or_return

  return nil
}

@(private = "file")
dma_params_init :: proc(ctx: ^Wayland_Context) -> error.Error {
  ctx.ids.dma_params = get_id(ctx, "zwp_linux_buffer_params_v1", { new_callback("created", param_created_callback), new_callback("failed", param_failed_callback), }, interface.DMA_INTERFACES[:]) or_return
  ctx.opcodes.dma_params_create_immed = get_request_opcode(ctx, "create_immed", ctx.ids.dma_params) or_return
  ctx.opcodes.dma_params_destroy = get_request_opcode(ctx, "destroy", ctx.ids.dma_params) or_return
  ctx.opcodes.dma_params_add = get_request_opcode(ctx, "add", ctx.ids.dma_params) or_return

  return nil
}

@private
write :: proc(ctx: ^Wayland_Context, arguments: []interface.Argument, object_id: u32, opcode: u32, loc := #caller_location) -> error.Error {
  object := get_object(ctx, object_id) or_return
  request := get_request(object, opcode) or_return

  start := ctx.output.vec.len

  vector.write(u32, &ctx.output, object_id) or_return
  vector.write(u16, &ctx.output, u16(opcode)) or_return

  total_len := vector.reserve(u16, &ctx.output) or_return

  log.debug("Writing (object, request, values)", object.interface.name, request.name, arguments)

  for kind, i in request.arguments {
    #partial switch kind {
    case .BoundNewId: vector.write(interface.BoundNewId, &ctx.output, arguments[i].(interface.BoundNewId)) or_return
    case .Uint: vector.write(interface.Uint, &ctx.output, arguments[i].(interface.Uint)) or_return
    case .Int: vector.write(interface.Int, &ctx.output, arguments[i].(interface.Int)) or_return
    case .Fixed: vector.write(interface.Fixed, &ctx.output, arguments[i].(interface.Fixed)) or_return
    case .Object: vector.write(interface.Object, &ctx.output, arguments[i].(interface.Object)) or_return
    case .UnBoundNewId:
      value := arguments[i].(interface.UnBoundNewId)
      l := len(value.interface)
      vector.write(u32, &ctx.output, u32(l)) or_return
      vector.write_n(u8, &ctx.output, ([]u8)(value.interface)) or_return
      vector.padd_n(&ctx.output, u32(mem.align_formula(l, size_of(u32)) - l)) or_return
      vector.write(interface.Uint, &ctx.output, value.version) or_return
      vector.write(interface.BoundNewId, &ctx.output, value.id) or_return
    case .Fd: vector.append(&ctx.out_fds, arguments[i].(interface.Fd)) or_return
    case:
    }
  }

  intrinsics.unaligned_store(total_len, u16(ctx.output.vec.len - start))

  return nil
}

@private
read :: proc(ctx: ^Wayland_Context) -> error.Error {
  ctx.values.len = 0
  bytes_len: u32 = 0

  start := ctx.input.offset
  object_id := vector.read(u32, &ctx.input) or_return
  opcode := vector.read(u16, &ctx.input) or_return
  size := vector.read(u16, &ctx.input) or_return

  object := get_object(ctx, object_id) or_return
  event := get_event(object, u32(opcode)) or_return

  for kind in event.arguments {
    #partial switch kind {
    case .Object: read_and_write(ctx, interface.Object) or_return
    case .Uint: read_and_write(ctx, interface.Uint) or_return
    case .Int: read_and_write(ctx, interface.Int) or_return
    case .Fixed: read_and_write(ctx, interface.Fixed) or_return
    case .BoundNewId: read_and_write(ctx, interface.BoundNewId) or_return
    case .String: read_and_write_collection(ctx, interface.String, &bytes_len) or_return
    case .Array: read_and_write_collection(ctx, interface.Array, &bytes_len) or_return
    case .Fd: read_fd(ctx) or_return
    case: return .OutOfBounds
    }
  }

  if ctx.input.offset - start != u32(size) do return .OutOfBounds

  values := ctx.values.data[0:ctx.values.len]
  log.debug("Reading (object, event, values)", object.interface.name, event.name, values)
  object.callbacks.data[opcode](ctx, object_id, values) or_return

  return nil
}

@private
read_and_write :: proc(ctx: ^Wayland_Context, $T: typeid) -> error.Error {
  value := vector.read(T, &ctx.input) or_return
  vector.append(&ctx.values, value)

  return nil
}

@private
read_fd :: proc(ctx: ^Wayland_Context) -> error.Error {
  vector.append(&ctx.values, vector.read(interface.Fd, &ctx.in_fds) or_return) or_return
  return nil
}

@private
read_and_write_collection :: proc(ctx: ^Wayland_Context, $T: typeid, length_ptr: ^u32) -> error.Error {
  start := length_ptr^

  length := vector.read(u32, &ctx.input) or_return
  bytes := vector.read_n(&ctx.input, u32(mem.align_formula(int(length), size_of(u32)))) or_return

  if bytes == nil {
    return .OutOfBounds
  }

  copy(ctx.bytes[start:], bytes)
  vector.append(&ctx.values, T(ctx.bytes[start:length])) or_return
  length_ptr^ += length

  return nil
}

@private
recv :: proc(ctx: ^Wayland_Context) -> error.Error {
  iovec := posix.iovec {
    iov_base = rawptr(&ctx.input.vec.data[0]),
    iov_len  = uint(ctx.input.vec.cap),
  }

  t_align := mem.align_formula(size_of(posix.FD) * 10, size_of(uint))
  cmsg_align := mem.align_formula(size_of(posix.cmsghdr), size_of(uint))

  buf := vector.new(u8, u32(cmsg_align + t_align), ctx.tmp_allocator) or_return

  msg := posix.msghdr {
    msg_iov = &iovec,
    msg_iovlen = 1,
    msg_control = rawptr(&buf.data[0]),
    msg_controllen = uint(buf.cap),
  }

  count := posix.recvmsg(ctx.socket, &msg, {})
  alig := u32(mem.align_formula(size_of(posix.cmsghdr), size_of(uint)))

  vector.reader_reset(&ctx.input, u32(count))
  vector.reader_reset(&ctx.in_fds, 0)

  cmsg := (^posix.cmsghdr)(msg.msg_control)
  if cmsg.cmsg_len <= 0 do return nil

  fd_count := (u32(cmsg.cmsg_len) - alig) / size_of(interface.Fd)
  fds := (cast([^]interface.Fd)(raw_data(buf.data[alig:alig + size_of(interface.Fd) * fd_count])))[0:fd_count]
  vector.write_n(interface.Fd, &ctx.in_fds, fds) or_return

  return nil
}

@private
send :: proc(ctx: ^Wayland_Context) -> error.Error {
  if ctx.output.vec.len == 0 {
    return nil
  }

  io := posix.iovec {
    iov_base = rawptr(&ctx.output.vec.data[0]),
    iov_len  = uint(ctx.output.vec.len),
  }

  cmsg_align := mem.align_formula(size_of(posix.cmsghdr), size_of(uint))
  fd_size := ctx.out_fds.len * size_of(interface.Fd)

  header := vector.buffer_new(u32(cmsg_align + mem.align_formula(int(fd_size), size_of(uint))), ctx.tmp_allocator) or_return

  cmsg: posix.cmsghdr
  cmsg.cmsg_len = uint(cmsg_align) + uint(fd_size)
  cmsg.cmsg_type = posix.SCM_RIGHTS
  cmsg.cmsg_level = posix.SOL_SOCKET

  vector.write(posix.cmsghdr, &header, cmsg) or_return
  vector.padd_n(&header, u32(cmsg_align - size_of(posix.cmsghdr))) or_return
  vector.write_n(interface.Fd, &header, vector.data(&ctx.out_fds)) or_return

  socket_msg := posix.msghdr {
    msg_name = nil,
    msg_namelen = 0,
    msg_iov = &io,
    msg_iovlen = 1,
    msg_control = rawptr(&header.vec.data[0]),
    msg_controllen = uint(mem.align_formula(int(header.vec.len), size_of(uint))),
    msg_flags = {},
  }

  if posix.sendmsg(ctx.socket, &socket_msg, {}) < 0 {
    return .SendMessageFailed
  }

  ctx.output.vec.len = 0
  ctx.out_fds.len = 0

  return nil
}

@private
object_append :: proc(ctx: ^Wayland_Context, callbacks: []CallbackConfig, interface: ^interface.Interface) -> error.Error {
  if len(callbacks) != len(interface.events) {
    log.error("Cannot create object interface if all events are not registred with callbacks")
    return .OutOfBounds
  }

  object := vector.one(&ctx.objects) or_return

  object.interface = interface
  object.callbacks = vector.new(Callback, u32(len(callbacks)), ctx.allocator) or_return
  vector.reserve_n(&object.callbacks, u32(len(callbacks))) or_return

  for callback in callbacks {
    opcode := get_event_opcode(interface, callback.name) or_return
    object.callbacks.data[opcode] = callback.function
  }

  return nil
}

@private
get_object :: proc(ctx: ^Wayland_Context, id: u32) -> (InterfaceObject, error.Error) {
  if ctx.objects.len < id {
    return ctx.objects.data[0], .OutOfBounds
  }

  return ctx.objects.data[id - 1], nil
}

@private
get_id :: proc(ctx: ^Wayland_Context, name: string, callbacks: []CallbackConfig, interfaces: []interface.Interface, loc := #caller_location) -> (id: u32, err: error.Error) {
  for &inter in interfaces {
    if inter.name == name {
      object_append(ctx, callbacks, &inter) or_return
      id = ctx.objects.len
      break
    }
  }

  if id == 0 {
    return 0, .OutOfBounds
  }

  return id, nil
}

@private
copy_id :: proc(ctx: ^Wayland_Context, id: u32) -> (i: u32, err: error.Error) {
  vector.append(&ctx.objects, get_object(ctx, id) or_return) or_return

  return ctx.objects.len, nil
}

@private
get_event :: proc(object: InterfaceObject, opcode: u32) -> (^interface.Event, error.Error) {
  if len(object.interface.events) <= int(opcode) {
    return nil, .OutOfBounds
  }

  return &object.interface.events[opcode], nil
}

@private
get_request :: proc(object: InterfaceObject, opcode: u32) -> (^interface.Request, error.Error) {
  if len(object.interface.requests) <= int(opcode) {
    return nil, .OutOfBounds
  }

  return &object.interface.requests[opcode], nil
}

@private
get_event_opcode :: proc(interface: ^interface.Interface, name: string) -> (u32, error.Error) {
  for event, i in interface.events {
    if event.name == name {
      return u32(i), nil
    }
  }

  return 0, .OutOfBounds
}

@private
get_request_opcode :: proc(ctx: ^Wayland_Context, name: string, object_id: u32) -> (i: u32, err: error.Error) {
  object := get_object(ctx, object_id) or_return
  requests := object.interface.requests

  for request, i in requests {
    if request.name == name {
      return u32(i), nil
    }
  }

  return 0, .OutOfBounds
}
