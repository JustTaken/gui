package wayland

import "base:intrinsics"
import "base:runtime"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:sys/posix"

import "core:fmt"
import "core:time"

import "./../collection"

import vk "./../vulkan"

Callback :: proc(_: ^Wayland_Context, _: u32, _: []Argument)
CallbackConfig :: struct {
  name:     string,
  function: Callback,
}

InterfaceObject :: struct {
  interface: ^Interface,
  callbacks: []Callback,
}

Modifier :: struct {
  format:   u32,
  modifier: u64,
}

Wayland_Context :: struct {
  socket:       posix.FD,
  objects:      collection.Vector(InterfaceObject),
  output_buffer:      collection.Vector(u8),
  input_buffer:       collection.Vector(u8),
  values:       collection.Vector(Argument),
  bytes:        []u8,
  in_fds:       []Fd,
  in_fds_len:         u32,
  in_fd_index:        u32,
  out_fds:      [^]Fd,
  out_fds_len:        u32,
  header:       []u8,
  modifiers:          collection.Vector(Modifier),
  display_id:         u32,
  registry_id:        u32,
  compositor_id:      u32,
  surface_id:         u32,
  seat_id:      u32,
  keyboard_id:        u32,
  pointer_id:         u32,
  xdg_wm_base_id:     u32,
  xdg_surface_id:     u32,
  xdg_toplevel_id:    u32,
  dma_id:       u32,
  dma_feedback_id:    u32,
  dma_params_id:      u32,
  buffer_base_id:     u32,
  get_registry_opcode:      u32,
  registry_bind_opcode:     u32,
  create_surface_opcode:    u32,
  surface_attach_opcode:    u32,
  surface_commit_opcode:    u32,
  surface_damage_opcode:    u32,
  ack_configure_opcode:     u32,
  get_pointer_opcode:       u32,
  get_keyboard_opcode:      u32,
  get_xdg_surface_opcode:   u32,
  get_toplevel_opcode:      u32,
  pong_opcode:        u32,
  destroy_buffer_opcode:    u32,
  dma_destroy_opcode:       u32,
  dma_create_param_opcode:  u32,
  dma_surface_feedback_opcode:    u32,
  dma_feedback_destroy_opcode:    u32,
  dma_params_create_immed_opcode: u32,
  dma_params_add_opcode:    u32,
  dma_params_destroy_opcode:      u32,
  dma_main_device:    u64,
  buffers:      []Buffer,
  buffer:       ^Buffer,
  width:        u32,
  height:       u32,
  running:      bool,
  keymap:       Keymap_Context,
  vk:           ^vk.Vulkan_Context,
  arena:        ^mem.Arena,
  allocator:          runtime.Allocator,
  tmp_arena:          ^mem.Arena,
  tmp_allocator:      runtime.Allocator,
}

init_wayland :: proc(
  ctx: ^Wayland_Context,
  v: ^vk.Vulkan_Context,
  width: u32,
  height: u32,
  frame_count: u32,
  arena: ^mem.Arena,
  tmp_arena: ^mem.Arena,
) -> Error {
  ctx.arena = arena
  ctx.allocator = mem.arena_allocator(arena)
  ctx.tmp_arena = tmp_arena
  ctx.tmp_allocator = mem.arena_allocator(tmp_arena)

  ctx.vk = v

  mark := mem.begin_arena_temp_memory(ctx.tmp_arena)
  defer mem.end_arena_temp_memory(mark)

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

  resize(ctx, width, height)

  ctx.values = collection.new_vec(Argument, 40, ctx.allocator)
  ctx.objects = collection.new_vec(InterfaceObject, 40, ctx.allocator)
  ctx.output_buffer = collection.new_vec(u8, 4096, ctx.allocator)
  ctx.input_buffer = collection.new_vec(u8, 4096, ctx.allocator)
  ctx.modifiers = collection.new_vec(Modifier, 512, ctx.allocator)
  ctx.bytes = make([]u8, 1024, ctx.allocator)
  ctx.header = make([]u8, 512, ctx.allocator)
  ctx.out_fds = ([^]Fd)(raw_data(ctx.header[mem.align_formula(size_of(posix.cmsghdr), size_of(uint)):]))
  ctx.out_fds_len = 0
  ctx.in_fds = make([]Fd, 10, ctx.allocator)
  ctx.in_fds_len = 0
  ctx.in_fd_index = 0

  ctx.input_buffer.cap = 0
  ctx.running = true
  ctx.buffers = make([]Buffer, frame_count, ctx.allocator)
  ctx.buffer = &ctx.buffers[0]

  buffer := ctx.buffer
  for i in 1 ..< frame_count {
    buffer.next = &ctx.buffers[i]
    buffer = buffer.next
  }

  buffer.next = ctx.buffer

  ctx.display_id = get_id(ctx, "wl_display", {new_callback("error", error_callback), new_callback("delete_id", delete_callback)}, WAYLAND_INTERFACES[:])
  ctx.registry_id = get_id(ctx, "wl_registry", { new_callback("global", global_callback), new_callback("global_remove", global_remove_callback), }, WAYLAND_INTERFACES[:])
  ctx.get_registry_opcode = get_request_opcode(ctx, "get_registry", ctx.display_id)

  write(ctx, {BoundNewId(ctx.registry_id)}, ctx.display_id, ctx.get_registry_opcode)
  send(ctx) or_return

  roundtrip(ctx) or_return
  send(ctx) or_return
  roundtrip(ctx) or_return

  dma_params_init(ctx)

  ctx.buffer_base_id = get_id(ctx, "wl_buffer", {new_callback("release", buffer_release_callback)}, WAYLAND_INTERFACES[:])
  ctx.destroy_buffer_opcode = get_request_opcode(ctx, "destroy", ctx.buffer_base_id)

  wayland_buffers_init(ctx)
  wayland_buffer_write_swap(ctx, ctx.buffer, ctx.width, ctx.height) or_return
  send(ctx) or_return

  return nil
}

deinit_wayland :: proc(ctx: ^Wayland_Context) {}
render :: proc(ctx: ^Wayland_Context) -> Error {
  time.sleep(time.Millisecond * 17)

  roundtrip(ctx) or_return

  wayland_buffer_write_swap(ctx, ctx.buffer, ctx.width, ctx.height) or_return

  send(ctx) or_return

  return nil
}

@(private = "file")
resize :: proc(ctx: ^Wayland_Context, width: u32, height: u32) {
  ctx.width = width
  ctx.height = height

  f_width := f32(width)
  f_height := f32(height)
  far := f32(1000)
  near := f32(1)

  scale := matrix[4, 4]f32{
    1 / f_width, 0, 0, 0, 
    0, -1 / f_height, 0, 0, 
    0, 0, 1 / (far - near), 0, 
    0, 0, 0, 1, 
  }

  translate := matrix[4, 4]f32{
    1, 0, 0, -f_width, 
    0, 1, 0, f_height, 
    0, 0, 1, -near / (far - near), 
    0, 0, 0.2, 0, 
  }

  vk.update_projection(ctx.vk, scale * translate)
}

@(private = "file")
roundtrip :: proc(ctx: ^Wayland_Context) -> Error {
  recv(ctx) or_return
  for read(ctx) {}

  return nil
}

@(private = "file")
create_surface :: proc(ctx: ^Wayland_Context) {
  ctx.surface_id = get_id(ctx, "wl_surface", { new_callback("enter", enter_callback), new_callback("leave", leave_callback), new_callback("preferred_buffer_scale", preferred_buffer_scale_callback), new_callback("preferred_buffer_transform", preferred_buffer_transform_callback), }, WAYLAND_INTERFACES[:])
  ctx.surface_attach_opcode = get_request_opcode(ctx, "attach", ctx.surface_id)
  ctx.surface_commit_opcode = get_request_opcode(ctx, "commit", ctx.surface_id)
  ctx.surface_damage_opcode = get_request_opcode(ctx, "damage", ctx.surface_id)

  write(ctx, {BoundNewId(ctx.surface_id)}, ctx.compositor_id, ctx.create_surface_opcode)
  create_dma(ctx)
}

@(private = "file")
create_xdg_surface :: proc(ctx: ^Wayland_Context) {
  ctx.xdg_surface_id = get_id(ctx, "xdg_surface", {new_callback("configure", configure_callback)}, XDG_INTERFACES[:])
  ctx.get_toplevel_opcode = get_request_opcode(ctx, "get_toplevel", ctx.xdg_surface_id)
  ctx.ack_configure_opcode = get_request_opcode(ctx, "ack_configure", ctx.xdg_surface_id)
  ctx.xdg_toplevel_id = get_id(ctx, "xdg_toplevel", { new_callback("configure", toplevel_configure_callback), new_callback("close", toplevel_close_callback), new_callback("configure_bounds", toplevel_configure_bounds_callback), new_callback("wm_capabilities", toplevel_wm_capabilities_callback), }, XDG_INTERFACES[:])

  write(ctx, {BoundNewId(ctx.xdg_surface_id), Object(ctx.surface_id)}, ctx.xdg_wm_base_id, ctx.get_xdg_surface_opcode)
  write(ctx, {BoundNewId(ctx.xdg_toplevel_id)}, ctx.xdg_surface_id, ctx.get_toplevel_opcode)
  write(ctx, {}, ctx.surface_id, ctx.surface_commit_opcode)
}

@(private = "file")
create_dma :: proc(ctx: ^Wayland_Context) {
  ctx.dma_feedback_id = get_id(ctx, "zwp_linux_dmabuf_feedback_v1", { new_callback("done", dma_done_callback), new_callback("format_table", dma_format_table_callback), new_callback("main_device", dma_main_device_callback), new_callback("tranche_done", dma_tranche_done_callback), new_callback("tranche_target_device", dma_tranche_target_device_callback), new_callback("tranche_formats", dma_tranche_formats_callback), new_callback("tranche_flags", dma_tranche_flags_callback), }, DMA_INTERFACES[:])
  ctx.dma_feedback_destroy_opcode = get_request_opcode(ctx, "destroy", ctx.dma_feedback_id)

  write(ctx, {BoundNewId(ctx.dma_feedback_id), Object(ctx.surface_id)}, ctx.dma_id, ctx.dma_surface_feedback_opcode)
}

@(private = "file")
dma_params_init :: proc(ctx: ^Wayland_Context) {
  ctx.dma_params_id = get_id(ctx, "zwp_linux_buffer_params_v1", { new_callback("created", param_created_callback), new_callback("failed", param_failed_callback), }, DMA_INTERFACES[:])
  ctx.dma_params_create_immed_opcode = get_request_opcode(ctx, "create_immed", ctx.dma_params_id)
  ctx.dma_params_add_opcode = get_request_opcode(ctx, "add", ctx.dma_params_id)
  ctx.dma_params_destroy_opcode = get_request_opcode(ctx, "destroy", ctx.dma_params_id)
}

write :: proc(ctx: ^Wayland_Context, arguments: []Argument, object_id: u32, opcode: u32) {
  object := get_object(ctx, object_id)
  request := get_request(object, opcode)

  start := ctx.output_buffer.len

  collection.vec_append_generic(&ctx.output_buffer, u32, object_id)
  collection.vec_append_generic(&ctx.output_buffer, u16, u16(opcode))

  total_len := collection.vec_reserve(&ctx.output_buffer, u16)

  for kind, i in request.arguments {
    #partial switch kind {
    case .BoundNewId:
      collection.vec_append_generic(&ctx.output_buffer, BoundNewId, arguments[i].(BoundNewId))
    case .Uint:
      collection.vec_append_generic(&ctx.output_buffer, Uint, arguments[i].(Uint))
    case .Int:
      collection.vec_append_generic(&ctx.output_buffer, Int, arguments[i].(Int))
    case .Fixed:
      collection.vec_append_generic(&ctx.output_buffer, Fixed, arguments[i].(Fixed))
    case .Object:
      collection.vec_append_generic(&ctx.output_buffer, Object, arguments[i].(Object))
    case .UnBoundNewId:
      value := arguments[i].(UnBoundNewId)
      l := len(value.interface)
      collection.vec_append_generic(&ctx.output_buffer, u32, u32(l))
      collection.vec_append_n(&ctx.output_buffer, ([]u8)(value.interface))
      collection.vec_add_n(&ctx.output_buffer, u32(mem.align_formula(l, size_of(u32)) - l))
      collection.vec_append_generic(&ctx.output_buffer, Uint, value.version)
      collection.vec_append_generic(&ctx.output_buffer, BoundNewId, value.id)
    case .Fd:
      insert_fd(ctx, arguments[i].(Fd))
    case:
    }
  }

  intrinsics.unaligned_store(total_len, u16(ctx.output_buffer.len - start))
}

@(private = "file")
read :: proc(ctx: ^Wayland_Context) -> bool {
  ctx.values.len = 0
  bytes_len: u32 = 0

  start := ctx.input_buffer.len
  object_id := collection.vec_read(&ctx.input_buffer, u32) or_return
  opcode := collection.vec_read(&ctx.input_buffer, u16) or_return
  size := collection.vec_read(&ctx.input_buffer, u16) or_return

  object := get_object(ctx, object_id)
  event := get_event(object, u32(opcode))

  for kind in event.arguments {
    #partial switch kind {
    case .Object:
      if !read_and_write(ctx, Object) do return false
    case .Uint:
      if !read_and_write(ctx, Uint) do return false
    case .Int:
      if !read_and_write(ctx, Int) do return false
    case .Fixed:
      if !read_and_write(ctx, Fixed) do return false
    case .BoundNewId:
      if !read_and_write(ctx, BoundNewId) do return false
    case .String:
      if !read_and_write_collection(ctx, String, &bytes_len) do return false
    case .Array:
      if !read_and_write_collection(ctx, Array, &bytes_len) do return false
    case .Fd:
      if !read_fd_and_write(ctx) do return false
    case:
      return false
    }
  }

  if ctx.input_buffer.len - start != u32(size) do return false

  values := ctx.values.data[0:ctx.values.len]
  object.callbacks[opcode](ctx, object_id, values)

  return true
}

@(private = "file")
read_and_write :: proc(ctx: ^Wayland_Context, $T: typeid) -> bool {
  value := collection.vec_read(&ctx.input_buffer, T) or_return
  collection.vec_append(&ctx.values, value)

  return true
}

@(private = "file")
read_fd_and_write :: proc(ctx: ^Wayland_Context) -> bool {
  collection.vec_append(&ctx.values, ctx.in_fds[ctx.in_fd_index])
  return true
}

@(private = "file")
read_and_write_collection :: proc(ctx: ^Wayland_Context, $T: typeid, length_ptr: ^u32) -> bool {
  start := length_ptr^

  length := collection.vec_read(&ctx.input_buffer, u32) or_return
  bytes := collection.vec_read_n(&ctx.input_buffer, u32(mem.align_formula(int(length), size_of(u32))))

  if bytes == nil {
    return false
  }

  copy(ctx.bytes[start:], bytes)
  collection.vec_append(&ctx.values, T(ctx.bytes[start:length]))
  length_ptr^ += length

  return true
}

@(private = "file")
recv :: proc(ctx: ^Wayland_Context) -> Error {
  iovec := posix.iovec {
    iov_base = raw_data(ctx.input_buffer.data),
    iov_len  = 4096,
  }

  t_size := size_of(posix.FD)
  t_align := mem.align_formula(t_size * 10, size_of(uint))
  cmsg_align := mem.align_formula(size_of(posix.cmsghdr), size_of(uint))

  buf := make([]u8, u32(cmsg_align + t_align), ctx.tmp_allocator)

  msg := posix.msghdr {
    msg_iov  = &iovec,
    msg_iovlen     = 1,
    msg_control    = raw_data(buf),
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

  ctx.input_buffer.cap = u32(count)
  ctx.input_buffer.len = 0

  return nil
}

@(private = "file")
insert_fd :: proc(ctx: ^Wayland_Context, fd: Fd) {
  ctx.out_fds[ctx.out_fds_len] = fd
  ctx.out_fds_len += 1
}

@(private = "file")
send :: proc(ctx: ^Wayland_Context) -> Error {
  if ctx.output_buffer.len == 0 {
    return nil
  }

  io := posix.iovec {
    iov_base = raw_data(ctx.output_buffer.data),
    iov_len  = uint(ctx.output_buffer.len),
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

  ctx.output_buffer.len = 0
  ctx.out_fds_len = 0

  return nil
}

@(private = "file")
ctx_append :: proc(ctx: ^Wayland_Context, callbacks: []CallbackConfig, interface: ^Interface) {
  if len(callbacks) != len(interface.events) {
    panic("Incorrect callback length")
  }

  err: mem.Allocator_Error
  object: InterfaceObject
  object.interface = interface
  if object.callbacks, err = make([]Callback, u32(len(callbacks)), ctx.allocator); err != nil do panic("Failed to allocate some memory")

  for callback in callbacks {
    opcode := get_event_opcode(interface, callback.name)
    object.callbacks[opcode] = callback.function
  }

  collection.vec_append(&ctx.objects, object)
}

@(private = "file")
get_object :: proc(ctx: ^Wayland_Context, id: u32) -> InterfaceObject {
  if len(ctx.objects.data) < int(id) {
    panic("OBject out of bounds")
  }

  return ctx.objects.data[id - 1]
}

@(private = "file")
get_id :: proc(
  ctx: ^Wayland_Context,
  name: string,
  callbacks: []CallbackConfig,
  interfaces: []Interface,
) -> u32 {
  for &inter in interfaces {
    if inter.name == name {
      defer ctx_append(ctx, callbacks, &inter)
      return ctx.objects.len + 1
    }
  }

  panic("Failed to get id")
}

copy_id :: proc(ctx: ^Wayland_Context, id: u32) -> u32 {
  defer collection.vec_append(&ctx.objects, get_object(ctx, id))
  return ctx.objects.len + 1
}

@(private = "file")
get_event :: proc(object: InterfaceObject, opcode: u32) -> ^Event {
  if len(object.interface.events) <= int(opcode) {
    panic("Request out of bounds")
  }
  return &object.interface.events[opcode]
}

@(private = "file")
get_request :: proc(object: InterfaceObject, opcode: u32) -> ^Request {
  if len(object.interface.requests) <= int(opcode) {
    panic("Request out of bounds")
  }

  return &object.interface.requests[opcode]
}

@(private = "file")
get_event_opcode :: proc(interface: ^Interface, name: string) -> u32 {
  for event, i in interface.events {
    if event.name == name {
      return u32(i)
    }
  }

  panic("event  opcode not found")
}

get_request_opcode :: proc(ctx: ^Wayland_Context, name: string, object_id: u32) -> u32 {
  requests := get_object(ctx, object_id).interface.requests

  for request, i in requests {
    if request.name == name {
      return u32(i)
    }
  }

  panic("request opcode not found")
}

@(private = "file")
new_callback :: proc(name: string, callback: Callback) -> CallbackConfig {
  return CallbackConfig{name = name, function = callback}
}

@(private = "file")
global_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {
  ok: bool
  str := arguments[1].(String)
  version := arguments[2].(Uint)
  interface_name := string(str[0:len(str) - 1])

  switch interface_name {
  case "xdg_wm_base":
    ctx.xdg_wm_base_id = get_id(ctx, interface_name, {new_callback("ping", ping_callback)}, XDG_INTERFACES[:])
    ctx.pong_opcode = get_request_opcode(ctx, "pong", ctx.xdg_wm_base_id)
    ctx.get_xdg_surface_opcode = get_request_opcode(ctx, "get_xdg_surface", ctx.xdg_wm_base_id)

    write(ctx, { arguments[0], UnBoundNewId { id = BoundNewId(ctx.xdg_wm_base_id), interface = str, version = version, }, }, ctx.registry_id, ctx.registry_bind_opcode)
    create_xdg_surface(ctx)
  case "wl_compositor":
    ctx.compositor_id = get_id(ctx, interface_name, {}, WAYLAND_INTERFACES[:])
    ctx.create_surface_opcode = get_request_opcode(ctx, "create_surface", ctx.compositor_id)

    write(ctx, { arguments[0], UnBoundNewId { id = BoundNewId(ctx.compositor_id), interface = str, version = version, }, }, ctx.registry_id, ctx.registry_bind_opcode)
    create_surface(ctx)
  case "wl_seat":
    ctx.seat_id = get_id(ctx, interface_name, {new_callback("capabilities", seat_capabilities), new_callback("name", seat_name)}, WAYLAND_INTERFACES[:])
    ctx.get_pointer_opcode = get_request_opcode(ctx, "get_pointer", ctx.seat_id)
    ctx.get_keyboard_opcode = get_request_opcode(ctx, "get_keyboard", ctx.seat_id)

    write(ctx, { arguments[0], UnBoundNewId{id = BoundNewId(ctx.seat_id), interface = str, version = version}, }, ctx.registry_id, ctx.registry_bind_opcode)
  case "zwp_linux_dmabuf_v1":
    ctx.dma_id = get_id(ctx, interface_name, { new_callback("format", dma_format_callback), new_callback("modifier", dma_modifier_callback), }, DMA_INTERFACES[:])
    ctx.dma_destroy_opcode = get_request_opcode(ctx, "destroy", ctx.dma_id)
    ctx.dma_create_param_opcode = get_request_opcode(ctx, "create_params", ctx.dma_id)
    ctx.dma_surface_feedback_opcode = get_request_opcode(ctx, "get_surface_feedback", ctx.dma_id)

    write(ctx, { arguments[0], UnBoundNewId{id = BoundNewId(ctx.dma_id), interface = str, version = version}, }, ctx.registry_id, ctx.registry_bind_opcode)
  }
}

@(private = "file")
global_remove_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}

@(private = "file")
seat_capabilities :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {
  SeatCapability :: enum {
    Pointer  = 0,
    Keyboard = 1,
    Touch    = 2,
  }

  SeatCapabilities :: bit_set[SeatCapability;u32]

  capabilities := transmute(SeatCapabilities)u32(arguments[0].(Uint))

  if .Pointer in capabilities {
    ctx.pointer_id = get_id(ctx, "wl_pointer", { new_callback("leave", pointer_leave_callback), new_callback("enter", pointer_enter_callback), new_callback("motion", pointer_motion_callback), new_callback("button", pointer_button_callback), new_callback("frame", pointer_frame_callback), new_callback("axis", pointer_axis_callback), new_callback("axis_source", pointer_axis_source_callback), new_callback("axis_stop", pointer_axis_stop_callback), new_callback("axis_discrete", pointer_axis_discrete_callback), new_callback("axis_value120", pointer_axis_value120_callback), new_callback("axis_relative_direction", pointer_axis_relative_direction_callback), }, WAYLAND_INTERFACES[:])
    write(ctx, {BoundNewId(ctx.pointer_id)}, ctx.seat_id, ctx.get_pointer_opcode)
  }

  if .Keyboard in capabilities {
    ctx.keyboard_id = get_id(ctx, "wl_keyboard", { new_callback("leave", keyboard_leave_callback), new_callback("enter", keyboard_enter_callback), new_callback("key", keyboard_key_callback), new_callback("keymap", keyboard_keymap_callback), new_callback("modifiers", keyboard_modifiers_callback), new_callback("repeat_info", keyboard_repeat_info_callback), }, WAYLAND_INTERFACES[:])
    write(ctx, {BoundNewId(ctx.keyboard_id)}, ctx.seat_id, ctx.get_keyboard_opcode)
  }
}

@(private = "file")
keyboard_keymap_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {
  err: Error
  size := uint(arguments[2].(Uint))

  data := ([^]u8)(posix.mmap(nil, size, {.READ}, {.PRIVATE}, posix.FD(arguments[1].(Fd)), 0))[0:size]
  defer posix.munmap(raw_data(data), size)

  if data == nil {
    panic("Mapped data is null")
  }

  mark := mem.begin_arena_temp_memory(ctx.tmp_arena)
  ctx.keymap, err = keymap_from_bytes(data, ctx.allocator, ctx.tmp_allocator)
  mem.end_arena_temp_memory(mark)

  if err != nil {
    fmt.println("Failed to create keymap")
  } else {
    fmt.println("Successfully read keymap file data")
  }
}

@(private = "file")
keyboard_enter_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}
@(private = "file")
keyboard_leave_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}
@(private = "file")
keyboard_key_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {
  register_code(&ctx.keymap, u32(arguments[2].(Uint)), u32(arguments[3].(Uint)))
}
@(private = "file")
keyboard_modifiers_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {
  set_modifiers(&ctx.keymap, u32(arguments[1].(Uint)))
}
@(private = "file")
keyboard_repeat_info_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}

@(private = "file")
pointer_enter_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}
@(private = "file")
pointer_leave_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}
@(private = "file")
pointer_motion_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}
@(private = "file")
pointer_button_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}
@(private = "file")
pointer_axis_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}
@(private = "file")
pointer_frame_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}
@(private = "file")
pointer_axis_source_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}
@(private = "file")
pointer_axis_stop_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}
@(private = "file")
pointer_axis_discrete_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}
@(private = "file")
pointer_axis_create_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}
@(private = "file")
pointer_axis_value120_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}
@(private = "file")
pointer_axis_relative_direction_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}

@(private = "file")
seat_name :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}

@(private = "file")
dma_modifier_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}
@(private = "file")
dma_format_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}
@(private = "file")
configure_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {
  write(ctx, {arguments[0]}, id, ctx.ack_configure_opcode)
}

@(private = "file")
ping_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {
  write(ctx, {arguments[0]}, ctx.xdg_wm_base_id, ctx.pong_opcode)
}

@(private = "file")
toplevel_configure_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {
  width := u32(arguments[0].(Int))
  height := u32(arguments[1].(Int))

  if width == 0 || height == 0 do return
  if width == ctx.width && height == ctx.height do return

  resize(ctx, width, height)
}

@(private = "file")
toplevel_close_callback :: proc(ctx: ^Wayland_Context, id: u32, arugments: []Argument) {
  ctx.running = false
}

@(private = "file")
toplevel_configure_bounds_callback :: proc(ctx: ^Wayland_Context, id: u32, arugments: []Argument) {}

@(private = "file")
toplevel_wm_capabilities_callback :: proc(ctx: ^Wayland_Context, id: u32, arugments: []Argument) {}

@(private = "file")
buffer_release_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {
  ctx.buffers[id - ctx.buffers[0].id].released = true
}

@(private = "file")
enter_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}
@(private = "file")
leave_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}
@(private = "file")
preferred_buffer_scale_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}
@(private = "file")
preferred_buffer_transform_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}

@(private = "file")
dma_tranche_flags_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}
@(private = "file")
dma_format_table_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {
  fd := posix.FD(arguments[0].(Fd))
  size := u32(arguments[1].(Uint))

  buf := ([^]u8)(posix.mmap(nil, uint(size), {.READ}, {.PRIVATE}, fd, 0))[0:size]
  defer posix.munmap(raw_data(buf), uint(size))

  if buf == nil do return

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

    collection.vec_append(&ctx.modifiers, mod)
  }
}

@(private = "file")
dma_main_device_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {
  ctx.dma_main_device = intrinsics.unaligned_load((^u64)(raw_data(arguments[0].(Array))))
}

@(private = "file")
dma_done_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {
  write(ctx, {}, id, ctx.dma_feedback_destroy_opcode)
}

@(private = "file")
dma_tranche_target_device_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}

@(private = "file")
dma_tranche_formats_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {
  array := arguments[0].(Array)
  indices := ([^]u16)(raw_data(array))[0:len(array) / 2]

  l: u32 = 0
  modifiers := ctx.modifiers
  ctx.modifiers.len = 0

  for i in indices {
    collection.vec_append(&ctx.modifiers, modifiers.data[i])
  }
}

@(private = "file")
dma_tranche_done_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}

@(private = "file")
param_created_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}

@(private = "file")
param_failed_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {
  panic("Failed to create dma buf server side")
}

@(private = "file")
delete_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {}

@(private = "file")
error_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []Argument) {
  fmt.println("error:", string(arguments[2].(String)))
}

