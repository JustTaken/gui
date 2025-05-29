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

import vk "lib:vulkan"
import "lib:collection/vector"
import "lib:error"

@private
Callback :: proc(_: ^Wayland_Context, _: u32, _: []Argument) -> error.Error
@private
CallbackConfig :: struct {
  name:     string,
  function: Callback,
}

@private
InterfaceObject :: struct {
  interface: ^Interface,
  callbacks: vector.Vector(Callback),
}

@private
Modifier :: struct {
  format:   u32,
  modifier: u64,
}

@private
Listen :: proc(ptr: rawptr, keymap: ^Keymap_Context, time: i64) -> error.Error

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
  values: vector.Vector(Argument),
  listeners: vector.Vector(KeyListener),
  bytes: []u8,
  in_fds: []Fd,
  in_fds_len: u32,
  in_fd_index: u32,
  out_fds: [^]Fd,
  out_fds_len: u32,
  header: []u8,
  modifiers: vector.Vector(Modifier),
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
  keymap: Keymap_Context,
  vk: ^vk.Vulkan_Context,
  arena: ^mem.Arena,
  allocator: runtime.Allocator,
  tmp_arena: ^mem.Arena,
  tmp_allocator: runtime.Allocator,
}

wayland_init :: proc(ctx: ^Wayland_Context, v: ^vk.Vulkan_Context, width: u32, height: u32, frame_count: u32, arena: ^mem.Arena, tmp_arena: ^mem.Arena) -> error.Error {
  log.info("Initializing Wayland")

  mark := mem.begin_arena_temp_memory(tmp_arena)
  defer mem.end_arena_temp_memory(mark)

  ctx.arena = arena
  ctx.allocator = mem.arena_allocator(arena)
  ctx.tmp_arena = tmp_arena
  ctx.tmp_allocator = mem.arena_allocator(tmp_arena)

  ctx.vk = v

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

  ctx.values = vector.new(Argument, 40, ctx.allocator) or_return
  ctx.objects = vector.new(InterfaceObject, 40, ctx.allocator) or_return
  ctx.output = vector.buffer_new(4096, ctx.allocator) or_return
  ctx.input = vector.buffer_new(4096, ctx.allocator) or_return
  ctx.modifiers = vector.new(Modifier, 512, ctx.allocator) or_return
  ctx.listeners = vector.new(KeyListener, 10, ctx.allocator) or_return
  ctx.bytes = make([]u8, 1024, ctx.allocator)
  ctx.header = make([]u8, 512, ctx.allocator)
  ctx.out_fds = ([^]Fd)(raw_data(ctx.header[mem.align_formula(size_of(posix.cmsghdr), size_of(uint)):]))
  ctx.out_fds_len = 0
  ctx.in_fds = make([]Fd, 10, ctx.allocator)
  ctx.in_fds_len = 0
  ctx.in_fd_index = 0

  // ctx.input_buffer.cap = 0
  ctx.running = true
  ctx.buffers = make([]Buffer, frame_count, ctx.allocator)
  ctx.buffer = &ctx.buffers[0]

  buffer := ctx.buffer
  for i in 1 ..< frame_count {
    buffer.next = &ctx.buffers[i]
    buffer = buffer.next
  }

  buffer.next = ctx.buffer

  ctx.display_id = get_id(ctx, "wl_display", {new_callback("error", error_callback), new_callback("delete_id", delete_callback)}, WAYLAND_INTERFACES[:]) or_return
  ctx.registry_id = get_id(ctx, "wl_registry", { new_callback("global", global_callback), new_callback("global_remove", global_remove_callback), }, WAYLAND_INTERFACES[:]) or_return
  ctx.get_registry_opcode = get_request_opcode(ctx, "get_registry", ctx.display_id) or_return

  write(ctx, {BoundNewId(ctx.registry_id)}, ctx.display_id, ctx.get_registry_opcode) or_return
  send(ctx) or_return

  roundtrip(ctx) or_return
  send(ctx) or_return
  roundtrip(ctx) or_return

  dma_params_init(ctx)

  ctx.buffer_base_id = get_id(ctx, "wl_buffer", {new_callback("release", buffer_release_callback)}, WAYLAND_INTERFACES[:]) or_return
  ctx.destroy_buffer_opcode = get_request_opcode(ctx, "destroy", ctx.buffer_base_id) or_return

  buffers_init(ctx) or_return
  buffer_write_swap(ctx, ctx.buffer, ctx.width, ctx.height) or_return
  send(ctx) or_return

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

  vk.update_projection(ctx.vk, projection) or_return

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
  ctx.surface_id = get_id(ctx, "wl_surface", { new_callback("enter", enter_callback), new_callback("leave", leave_callback), new_callback("preferred_buffer_scale", preferred_buffer_scale_callback), new_callback("preferred_buffer_transform", preferred_buffer_transform_callback), }, WAYLAND_INTERFACES[:]) or_return
  ctx.surface_attach_opcode = get_request_opcode(ctx, "attach", ctx.surface_id) or_return
  ctx.surface_commit_opcode = get_request_opcode(ctx, "commit", ctx.surface_id) or_return
  ctx.surface_damage_opcode = get_request_opcode(ctx, "damage", ctx.surface_id) or_return

  write(ctx, {BoundNewId(ctx.surface_id)}, ctx.compositor_id, ctx.create_surface_opcode) or_return
  dma_create(ctx) or_return

  return nil
}

@(private = "file")
xdg_surface_create :: proc(ctx: ^Wayland_Context) -> error.Error {
  ctx.xdg_surface_id = get_id(ctx, "xdg_surface", {new_callback("configure", configure_callback)}, XDG_INTERFACES[:]) or_return
  ctx.get_toplevel_opcode = get_request_opcode(ctx, "get_toplevel", ctx.xdg_surface_id) or_return
  ctx.ack_configure_opcode = get_request_opcode(ctx, "ack_configure", ctx.xdg_surface_id) or_return

  ctx.xdg_toplevel_id = get_id(ctx, "xdg_toplevel", { new_callback("configure", toplevel_configure_callback), new_callback("close", toplevel_close_callback), new_callback("configure_bounds", toplevel_configure_bounds_callback), new_callback("wm_capabilities", toplevel_wm_capabilities_callback), }, XDG_INTERFACES[:]) or_return

  write(ctx, {BoundNewId(ctx.xdg_surface_id), Object(ctx.surface_id)}, ctx.xdg_wm_base_id, ctx.get_xdg_surface_opcode) or_return
  write(ctx, {BoundNewId(ctx.xdg_toplevel_id)}, ctx.xdg_surface_id, ctx.get_toplevel_opcode) or_return
  write(ctx, {}, ctx.surface_id, ctx.surface_commit_opcode) or_return

  return nil
}

@(private = "file")
dma_create :: proc(ctx: ^Wayland_Context) -> error.Error {
  ctx.dma_feedback_id = get_id(ctx, "zwp_linux_dmabuf_feedback_v1", { new_callback("done", dma_done_callback), new_callback("format_table", dma_format_table_callback), new_callback("main_device", dma_main_device_callback), new_callback("tranche_done", dma_tranche_done_callback), new_callback("tranche_target_device", dma_tranche_target_device_callback), new_callback("tranche_formats", dma_tranche_formats_callback), new_callback("tranche_flags", dma_tranche_flags_callback), }, DMA_INTERFACES[:]) or_return
  ctx.dma_feedback_destroy_opcode = get_request_opcode(ctx, "destroy", ctx.dma_feedback_id) or_return

  write(ctx, {BoundNewId(ctx.dma_feedback_id), Object(ctx.surface_id)}, ctx.dma_id, ctx.dma_surface_feedback_opcode) or_return

  return nil
}

@(private = "file")
dma_params_init :: proc(ctx: ^Wayland_Context) -> error.Error {
  ctx.dma_params_id = get_id(ctx, "zwp_linux_buffer_params_v1", { new_callback("created", param_created_callback), new_callback("failed", param_failed_callback), }, DMA_INTERFACES[:]) or_return
  ctx.dma_params_create_immed_opcode = get_request_opcode(ctx, "create_immed", ctx.dma_params_id) or_return
  ctx.dma_params_destroy_opcode = get_request_opcode(ctx, "destroy", ctx.dma_params_id) or_return
  ctx.dma_params_add_opcode = get_request_opcode(ctx, "add", ctx.dma_params_id) or_return

  return nil
}

@private
write :: proc(ctx: ^Wayland_Context, arguments: []Argument, object_id: u32, opcode: u32, loc := #caller_location) -> error.Error {
  object := get_object(ctx, object_id) or_return
  request := get_request(object, opcode) or_return

  start := ctx.output.offset

  vector.write(u32, &ctx.output, object_id) or_return
  vector.write(u16, &ctx.output, u16(opcode)) or_return

  total_len := vector.reserve(u16, &ctx.output) or_return

  log.debug("Writing (object, request, values)", object.interface.name, request.name, arguments)

  for kind, i in request.arguments {
    #partial switch kind {
    case .BoundNewId: vector.write(BoundNewId, &ctx.output, arguments[i].(BoundNewId)) or_return
    case .Uint: vector.write(Uint, &ctx.output, arguments[i].(Uint)) or_return
    case .Int: vector.write(Int, &ctx.output, arguments[i].(Int)) or_return
    case .Fixed: vector.write(Fixed, &ctx.output, arguments[i].(Fixed)) or_return
    case .Object: vector.write(Object, &ctx.output, arguments[i].(Object)) or_return
    case .UnBoundNewId:
      value := arguments[i].(UnBoundNewId)
      l := len(value.interface)
      vector.write(u32, &ctx.output, u32(l)) or_return
      vector.write_n(u8, &ctx.output, ([]u8)(value.interface)) or_return
      vector.padd_n(&ctx.output, u32(mem.align_formula(l, size_of(u32)) - l)) or_return
      vector.write(Uint, &ctx.output, value.version) or_return
      vector.write(BoundNewId, &ctx.output, value.id) or_return
    case .Fd:
      fd_append(ctx, arguments[i].(Fd))
    case:
    }
  }

  intrinsics.unaligned_store(total_len, u16(ctx.output.offset - start))

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
    case .Object: read_and_write(ctx, Object) or_return
    case .Uint: read_and_write(ctx, Uint) or_return
    case .Int: read_and_write(ctx, Int) or_return
    case .Fixed: read_and_write(ctx, Fixed) or_return
    case .BoundNewId: read_and_write(ctx, BoundNewId) or_return
    case .String: read_and_write_collection(ctx, String, &bytes_len) or_return
    case .Array: read_and_write_collection(ctx, Array, &bytes_len) or_return
    case .Fd: read_fd_and_write(ctx) or_return
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
read_fd_and_write :: proc(ctx: ^Wayland_Context) -> error.Error {
  vector.append(&ctx.values, ctx.in_fds[ctx.in_fd_index]) or_return
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

  t_size := size_of(posix.FD)
  t_align := mem.align_formula(t_size * 10, size_of(uint))
  cmsg_align := mem.align_formula(size_of(posix.cmsghdr), size_of(uint))

  buf := make([]u8, u32(cmsg_align + t_align), ctx.tmp_allocator)

  msg := posix.msghdr {
    msg_iov  = &iovec,
    msg_iovlen     = 1,
    msg_control    = rawptr(&buf[0]),
    msg_controllen = len(buf),
  }

  count := posix.recvmsg(ctx.socket, &msg, {})
  alig := u32(mem.align_formula(size_of(posix.cmsghdr), size_of(uint)))
  cmsg := (^posix.cmsghdr)(msg.msg_control)
  ctx.in_fd_index = 0

  if cmsg.cmsg_len > 0 {
    ctx.in_fds_len = (u32(cmsg.cmsg_len) - alig) / size_of(Fd)

    for i in 0 ..< ctx.in_fds_len {
      ctx.in_fds[i] = intrinsics.unaligned_load((^Fd)(raw_data(buf[alig + size_of(Fd) * i:])) )
    }
  }

  vector.reader_reset(&ctx.input, u32(count))

  return nil
}

@private
fd_append :: proc(ctx: ^Wayland_Context, fd: Fd) {
  ctx.out_fds[ctx.out_fds_len] = fd
  ctx.out_fds_len += 1
}

@private
send :: proc(ctx: ^Wayland_Context) -> error.Error {
  if ctx.output.offset == 0 {
    return nil
  }

  io := posix.iovec {
    iov_base = rawptr(&ctx.output.vec.data[0]),
    iov_len  = uint(ctx.output.offset),
  }

  cmsg_align := mem.align_formula(size_of(posix.cmsghdr), size_of(uint))
  fd_size := ctx.out_fds_len * size_of(Fd)

  socket_msg := posix.msghdr {
    msg_name       = nil,
    msg_namelen    = 0,
    msg_iov  = &io,
    msg_iovlen     = 1,
    msg_control    = raw_data(ctx.header),
    msg_controllen = uint(cmsg_align + mem.align_formula(int(fd_size), size_of(uint))),
    msg_flags      = {},
  }

  cmsg := (^posix.cmsghdr)(socket_msg.msg_control)
  cmsg.cmsg_len = uint(cmsg_align) + uint(fd_size)
  cmsg.cmsg_type = posix.SCM_RIGHTS
  cmsg.cmsg_level = posix.SOL_SOCKET

  if posix.sendmsg(ctx.socket, &socket_msg, {}) < 0 {
    return .SendMessageFailed
  }

  ctx.output.offset = 0
  ctx.out_fds_len = 0

  return nil
}

@private
ctx_append :: proc(ctx: ^Wayland_Context, callbacks: []CallbackConfig, interface: ^Interface) -> error.Error {
  if len(callbacks) != len(interface.events) {
    return .OutOfBounds
  }

  err: mem.Allocator_Error
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
get_id :: proc(ctx: ^Wayland_Context, name: string, callbacks: []CallbackConfig, interfaces: []Interface, loc := #caller_location) -> (id: u32, err: error.Error) {
  for &inter in interfaces {
    if inter.name == name {
      ctx_append(ctx, callbacks, &inter) or_return
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
get_event :: proc(object: InterfaceObject, opcode: u32) -> (^Event, error.Error) {
  if len(object.interface.events) <= int(opcode) {
    return nil, .OutOfBounds
  }

  return &object.interface.events[opcode], nil
}

@private
get_request :: proc(object: InterfaceObject, opcode: u32) -> (^Request, error.Error) {
  if len(object.interface.requests) <= int(opcode) {
    return nil, .OutOfBounds
  }

  return &object.interface.requests[opcode], nil
}

@private
get_event_opcode :: proc(interface: ^Interface, name: string) -> (u32, error.Error) {
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

@private
new_callback :: proc(name: string, callback: Callback) -> CallbackConfig {
  return CallbackConfig{name = name, function = callback}
}

@private
global_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  ok: bool
  str := arguments[1].(String)
  version := arguments[2].(Uint)
  interface_name := string(str[0:len(str) - 1])

  switch interface_name {
  case "xdg_wm_base":
    ctx.xdg_wm_base_id = get_id(ctx, interface_name, {new_callback("ping", ping_callback)}, XDG_INTERFACES[:]) or_return
    ctx.pong_opcode = get_request_opcode(ctx, "pong", ctx.xdg_wm_base_id) or_return
    ctx.get_xdg_surface_opcode = get_request_opcode(ctx, "get_xdg_surface", ctx.xdg_wm_base_id) or_return

    write(ctx, { arguments[0], UnBoundNewId { id = BoundNewId(ctx.xdg_wm_base_id), interface = str, version = version, }, }, ctx.registry_id, ctx.registry_bind_opcode) or_return
    xdg_surface_create(ctx)
  case "wl_compositor":
    ctx.compositor_id = get_id(ctx, interface_name, {}, WAYLAND_INTERFACES[:]) or_return
    ctx.create_surface_opcode = get_request_opcode(ctx, "create_surface", ctx.compositor_id) or_return

    write(ctx, { arguments[0], UnBoundNewId { id = BoundNewId(ctx.compositor_id), interface = str, version = version, }, }, ctx.registry_id, ctx.registry_bind_opcode) or_return
    surface_create(ctx)
  case "wl_seat":
    ctx.seat_id = get_id(ctx, interface_name, {new_callback("capabilities", seat_capabilities), new_callback("name", seat_name)}, WAYLAND_INTERFACES[:]) or_return
    ctx.get_pointer_opcode = get_request_opcode(ctx, "get_pointer", ctx.seat_id) or_return
    ctx.get_keyboard_opcode = get_request_opcode(ctx, "get_keyboard", ctx.seat_id) or_return

    write(ctx, { arguments[0], UnBoundNewId{id = BoundNewId(ctx.seat_id), interface = str, version = version}, }, ctx.registry_id, ctx.registry_bind_opcode) or_return
  case "zwp_linux_dmabuf_v1":
    ctx.dma_id = get_id(ctx, interface_name, { new_callback("format", dma_format_callback), new_callback("modifier", dma_modifier_callback), }, DMA_INTERFACES[:]) or_return
    ctx.dma_destroy_opcode = get_request_opcode(ctx, "destroy", ctx.dma_id) or_return
    ctx.dma_create_param_opcode = get_request_opcode(ctx, "create_params", ctx.dma_id) or_return
    ctx.dma_surface_feedback_opcode = get_request_opcode(ctx, "get_surface_feedback", ctx.dma_id) or_return

    write(ctx, { arguments[0], UnBoundNewId{id = BoundNewId(ctx.dma_id), interface = str, version = version}, }, ctx.registry_id, ctx.registry_bind_opcode) or_return
  }

  return nil
}

@private
global_remove_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
}

@private
seat_capabilities :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  SeatCapability :: enum {
    Pointer  = 0,
    Keyboard = 1,
    Touch    = 2,
  }

  SeatCapabilities :: bit_set[SeatCapability;u32]

  capabilities := transmute(SeatCapabilities)u32(arguments[0].(Uint))

  if .Pointer in capabilities {
    ctx.pointer_id = get_id(ctx, "wl_pointer", { new_callback("leave", pointer_leave_callback), new_callback("enter", pointer_enter_callback), new_callback("motion", pointer_motion_callback), new_callback("button", pointer_button_callback), new_callback("frame", pointer_frame_callback), new_callback("axis", pointer_axis_callback), new_callback("axis_source", pointer_axis_source_callback), new_callback("axis_stop", pointer_axis_stop_callback), new_callback("axis_discrete", pointer_axis_discrete_callback), new_callback("axis_value120", pointer_axis_value120_callback), new_callback("axis_relative_direction", pointer_axis_relative_direction_callback), }, WAYLAND_INTERFACES[:]) or_return
    write(ctx, {BoundNewId(ctx.pointer_id)}, ctx.seat_id, ctx.get_pointer_opcode) or_return
  }

  if .Keyboard in capabilities {
    ctx.keyboard_id = get_id(ctx, "wl_keyboard", { new_callback("leave", keyboard_leave_callback), new_callback("enter", keyboard_enter_callback), new_callback("key", keyboard_key_callback), new_callback("keymap", keyboard_keymap_callback), new_callback("modifiers", keyboard_modifiers_callback), new_callback("repeat_info", keyboard_repeat_info_callback), }, WAYLAND_INTERFACES[:]) or_return
    write(ctx, {BoundNewId(ctx.keyboard_id)}, ctx.seat_id, ctx.get_keyboard_opcode) or_return
  }

  return nil
}

@private
keyboard_keymap_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  size := uint(arguments[2].(Uint))

  data := ([^]u8)(posix.mmap(nil, size, {.READ}, {.PRIVATE}, posix.FD(arguments[1].(Fd)), 0))[0:size]
  defer posix.munmap(raw_data(data), size)

  if data == nil {
    return .OutOfMemory
  }

  mark := mem.begin_arena_temp_memory(ctx.tmp_arena)
  ctx.keymap = keymap_from_bytes(data, ctx.allocator, ctx.tmp_allocator) or_return
  mem.end_arena_temp_memory(mark)

  return nil
}

@private
keyboard_enter_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}
@private
keyboard_leave_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}
@private
keyboard_key_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  register_code(&ctx.keymap, u32(arguments[2].(Uint)), u32(arguments[3].(Uint)))

  return nil
}
@private
keyboard_modifiers_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  set_modifiers(&ctx.keymap, u32(arguments[1].(Uint)))

  return nil
}
@private
keyboard_repeat_info_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}

@private
pointer_enter_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}
@private
pointer_leave_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}
@private
pointer_motion_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}
@private
pointer_button_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}
@private
pointer_axis_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}
@private
pointer_frame_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}
@private
pointer_axis_source_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}
@private
pointer_axis_stop_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}
@private
pointer_axis_discrete_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}
@private
pointer_axis_create_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}
@private
pointer_axis_value120_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}
@private
pointer_axis_relative_direction_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}

@private
seat_name :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
}

@private
dma_modifier_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}
@private
dma_format_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}
@private
configure_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  write(ctx, {arguments[0]}, id, ctx.ack_configure_opcode)

  return nil
}

@private
ping_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  write(ctx, {arguments[0]}, ctx.xdg_wm_base_id, ctx.pong_opcode)

  return nil
}

@private
toplevel_configure_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  width := u32(arguments[0].(Int))
  height := u32(arguments[1].(Int))

  if width == 0 || height == 0 do return nil
  if width == ctx.width && height == ctx.height do return nil

  resize(ctx, width, height) or_return

  return nil
}

@private
toplevel_close_callback :: proc(ctx: ^Wayland_Context, id: u32, arugments: []Argument) -> error.Error {
  ctx.running = false

  return nil
}

@private
toplevel_configure_bounds_callback :: proc(ctx: ^Wayland_Context, id: u32, arugments: []Argument) -> error.Error {
  return nil
  
}

@private
toplevel_wm_capabilities_callback :: proc(ctx: ^Wayland_Context, id: u32, arugments: []Argument) -> error.Error {
  return nil
  
}

@private
buffer_release_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  ctx.buffers[id - ctx.buffers[0].id].released = true
  return nil
}

@private
enter_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}
@private
leave_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}
@private
preferred_buffer_scale_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}
@private
preferred_buffer_transform_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}

@private
dma_tranche_flags_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}
@private
dma_format_table_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  fd := posix.FD(arguments[0].(Fd))
  size := u32(arguments[1].(Uint))

  buf := ([^]u8)(posix.mmap(nil, uint(size), {.READ}, {.PRIVATE}, fd, 0))[0:size]
  defer posix.munmap(raw_data(buf), uint(size))

  if buf == nil do return .OutOfMemory

  format_size: u32 = size_of(u32)
  modifier_size: u32 = size_of(u64)
  tuple_size := u32(mem.align_formula(int(format_size + modifier_size), int(modifier_size)))

  count := size / tuple_size
  for i in 0 ..< count {
    offset := u32(i) * tuple_size

    format := intrinsics.unaligned_load((^u32)(raw_data(buf[offset:][0:format_size])))
    modifier := intrinsics.unaligned_load((^u64)(raw_data(buf[offset + modifier_size:][0:modifier_size])))

    mod := Modifier {
      format   = format,
      modifier = modifier,
    }

    vector.append(&ctx.modifiers, mod)
  }

  return nil
}

@private
dma_main_device_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  ctx.dma_main_device = intrinsics.unaligned_load((^u64)(raw_data(arguments[0].(Array))))

  return nil
}

@private
dma_done_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  write(ctx, {}, id, ctx.dma_feedback_destroy_opcode)

  return nil
}

@private
dma_tranche_target_device_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}

@private
dma_tranche_formats_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  array := arguments[0].(Array)
  indices := ([^]u16)(raw_data(array))[0:len(array) / 2]

  l: u32 = 0
  modifiers := ctx.modifiers
  ctx.modifiers.len = 0

  for i in indices {
    vector.append(&ctx.modifiers, modifiers.data[i])
  }

  return nil
}

@private
dma_tranche_done_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}

@private
param_created_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}

@private
param_failed_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return .DmaBufFailed
}

@private
delete_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  return nil
  
}

@private
error_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) -> error.Error {
  log.error(string(arguments[2].(String)))

  return nil
}
