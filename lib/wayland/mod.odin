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

Wayland_Context :: struct {
  socket: posix.FD,
  objects: vector.Vector(InterfaceObject),
  output: vector.Buffer,
  input: vector.Buffer,
  values: vector.Vector(interface.Argument),
  listeners: vector.Vector(KeyListener),
  modifiers: vector.Vector(Modifier),
  bytes: []u8,
  in_fds: vector.Buffer,
  out_fds: vector.Vector(interface.Fd),
  header: []u8,
  display_id: u32,
  registry_id: u32,
  compositor_id: u32,
  surface_id: u32,
  seat_id: u32,
  keyboard_id: u32,
  pointer_id: u32,
  xdg_wm_base_id: u32,
  xdg_surface_id: u32,
  xdg_toplevel_id: u32,
  dma_id: u32,
  dma_feedback_id: u32,
  dma_params_id: u32,
  buffer_base_id: u32,
  get_registry_opcode: u32,
  registry_bind_opcode: u32,
  create_surface_opcode: u32,
  surface_attach_opcode: u32,
  surface_commit_opcode: u32,
  surface_damage_opcode: u32,
  ack_configure_opcode:  u32,
  get_pointer_opcode: u32,
  get_keyboard_opcode: u32,
  get_xdg_surface_opcode: u32,
  get_toplevel_opcode: u32,
  pong_opcode: u32,
  destroy_buffer_opcode: u32,
  dma_destroy_opcode: u32,
  dma_create_param_opcode: u32,
  dma_surface_feedback_opcode: u32,
  dma_feedback_destroy_opcode: u32,
  dma_params_create_immed_opcode: u32,
  dma_params_add_opcode: u32,
  dma_params_destroy_opcode: u32,
  dma_main_device: u64,
  buffers: []Buffer,
  buffer: ^Buffer,
  width: u32,
  height: u32,
  running: bool,
  keymap: xkb.Keymap_Context,
  vk: ^vulkan.Vulkan_Context,
  arena: ^mem.Arena,
  allocator: runtime.Allocator,
  tmp_arena: ^mem.Arena,
  tmp_allocator: runtime.Allocator,
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

  ctx.buffers = make([]Buffer, frame_count, ctx.allocator)
  ctx.buffer = &ctx.buffers[0]

  buffer := ctx.buffer
  for i in 1 ..< frame_count {
    buffer.next = &ctx.buffers[i]
    buffer = buffer.next
  }

  buffer.next = ctx.buffer

  ctx.display_id = get_id(ctx, "wl_display", {new_callback("error", error_callback), new_callback("delete_id", delete_callback)}, interface.WAYLAND_INTERFACES[:]) or_return
  ctx.registry_id = get_id(ctx, "wl_registry", { new_callback("global", global_callback), new_callback("global_remove", global_remove_callback), }, interface.WAYLAND_INTERFACES[:]) or_return
  ctx.get_registry_opcode = get_request_opcode(ctx, "get_registry", ctx.display_id) or_return

  write(ctx, {interface.BoundNewId(ctx.registry_id)}, ctx.display_id, ctx.get_registry_opcode) or_return
  send(ctx) or_return

  roundtrip(ctx) or_return
  send(ctx) or_return
  roundtrip(ctx) or_return

  dma_params_init(ctx) or_return

  ctx.buffer_base_id = get_id(ctx, "wl_buffer", {new_callback("release", buffer_release_callback)}, interface.WAYLAND_INTERFACES[:]) or_return
  ctx.destroy_buffer_opcode = get_request_opcode(ctx, "destroy", ctx.buffer_base_id) or_return

  buffers_init(ctx) or_return
  buffer_write_swap(ctx, ctx.buffer, ctx.width, ctx.height) or_return
  send(ctx) or_return

  ctx.running = true

  return nil
}

render :: proc(ctx: ^Wayland_Context) -> error.Error {
  time.sleep(time.Millisecond * 30)

  roundtrip(ctx) or_return
  handle_input(ctx) or_return

  buffer_write_swap(ctx, ctx.buffer, ctx.width, ctx.height) or_return

  send(ctx) or_return

  return nil
}

@private
handle_input :: proc(ctx: ^Wayland_Context) -> error.Error {
  now := time.now()._nsec

  for i in 0..<ctx.listeners.len {
    listener := &ctx.listeners.data[i]
    listener.f(listener.ptr, &ctx.keymap, now) or_return
  }

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
    0, 1 / (tan_fovy), 0, 0, 
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
  ctx.surface_id = get_id(ctx, "wl_surface", { new_callback("enter", enter_callback), new_callback("leave", leave_callback), new_callback("preferred_buffer_scale", preferred_buffer_scale_callback), new_callback("preferred_buffer_transform", preferred_buffer_transform_callback), }, interface.WAYLAND_INTERFACES[:]) or_return
  ctx.surface_attach_opcode = get_request_opcode(ctx, "attach", ctx.surface_id) or_return
  ctx.surface_commit_opcode = get_request_opcode(ctx, "commit", ctx.surface_id) or_return
  ctx.surface_damage_opcode = get_request_opcode(ctx, "damage", ctx.surface_id) or_return

  write(ctx, {interface.BoundNewId(ctx.surface_id)}, ctx.compositor_id, ctx.create_surface_opcode) or_return
  dma_create(ctx) or_return

  return nil
}

@private
xdg_surface_create :: proc(ctx: ^Wayland_Context) -> error.Error {
  ctx.xdg_surface_id = get_id(ctx, "xdg_surface", {new_callback("configure", configure_callback)}, interface.XDG_INTERFACES[:]) or_return
  ctx.get_toplevel_opcode = get_request_opcode(ctx, "get_toplevel", ctx.xdg_surface_id) or_return
  ctx.ack_configure_opcode = get_request_opcode(ctx, "ack_configure", ctx.xdg_surface_id) or_return

  ctx.xdg_toplevel_id = get_id(ctx, "xdg_toplevel", { new_callback("configure", toplevel_configure_callback), new_callback("close", toplevel_close_callback), new_callback("configure_bounds", toplevel_configure_bounds_callback), new_callback("wm_capabilities", toplevel_wm_capabilities_callback), }, interface.XDG_INTERFACES[:]) or_return

  write(ctx, {interface.BoundNewId(ctx.xdg_surface_id), interface.Object(ctx.surface_id)}, ctx.xdg_wm_base_id, ctx.get_xdg_surface_opcode) or_return
  write(ctx, {interface.BoundNewId(ctx.xdg_toplevel_id)}, ctx.xdg_surface_id, ctx.get_toplevel_opcode) or_return
  write(ctx, {}, ctx.surface_id, ctx.surface_commit_opcode) or_return

  return nil
}

@(private = "file")
dma_create :: proc(ctx: ^Wayland_Context) -> error.Error {
  ctx.dma_feedback_id = get_id(ctx, "zwp_linux_dmabuf_feedback_v1", { new_callback("done", dma_done_callback), new_callback("format_table", dma_format_table_callback), new_callback("main_device", dma_main_device_callback), new_callback("tranche_done", dma_tranche_done_callback), new_callback("tranche_target_device", dma_tranche_target_device_callback), new_callback("tranche_formats", dma_tranche_formats_callback), new_callback("tranche_flags", dma_tranche_flags_callback), }, interface.DMA_INTERFACES[:]) or_return
  ctx.dma_feedback_destroy_opcode = get_request_opcode(ctx, "destroy", ctx.dma_feedback_id) or_return

  write(ctx, {interface.BoundNewId(ctx.dma_feedback_id), interface.Object(ctx.surface_id)}, ctx.dma_id, ctx.dma_surface_feedback_opcode) or_return

  return nil
}

@(private = "file")
dma_params_init :: proc(ctx: ^Wayland_Context) -> error.Error {
  ctx.dma_params_id = get_id(ctx, "zwp_linux_buffer_params_v1", { new_callback("created", param_created_callback), new_callback("failed", param_failed_callback), }, interface.DMA_INTERFACES[:]) or_return
  ctx.dma_params_create_immed_opcode = get_request_opcode(ctx, "create_immed", ctx.dma_params_id) or_return
  ctx.dma_params_destroy_opcode = get_request_opcode(ctx, "destroy", ctx.dma_params_id) or_return
  ctx.dma_params_add_opcode = get_request_opcode(ctx, "add", ctx.dma_params_id) or_return

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
