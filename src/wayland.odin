package main

import wl "wayland"
import "core:os"
import "core:mem"
import "core:sys/posix"
import "core:path/filepath"
import "base:intrinsics"
import "base:runtime"

import "core:fmt"

Vector :: struct(T: typeid) {
  data: []T,
  cap: u32,
  len: u32,
}

Callback :: proc(^WaylandContext, u32, []wl.Argument)
CallbackConfig :: struct {
  name: string,
  function: Callback,
}

InterfaceObject :: struct {
  interface: ^wl.Interface,
  callbacks: []Callback,
}

Buffer :: struct {
  data: []u8,
  id: u32,
  offset: u32,
  update: bool,
  released: bool,
}

WaylandContext :: struct {
  socket: posix.FD,
  objects: Vector(InterfaceObject),
  output_buffer: Vector(u8),
  input_buffer: Vector(u8),
  values: Vector(wl.Argument),
  bytes: []u8,

  display_id: u32,
  registry_id: u32,
  shm_id: u32,
  compositor_id: u32,
  surface_id: u32,
  xdg_wm_base_id: u32,
  xdg_surface_id: u32,
  xdg_toplevel_id: u32,
  shm_pool_id: u32,

  get_registry_opcode: u32,
  registry_bind_opcode: u32,
  create_shm_pool_opcode: u32,
  create_surface_opcode: u32,
  create_buffer_opcode: u32,
  surface_attach_opcode: u32,
  surface_commit_opcode: u32,
  ack_configure_opcode: u32,
  get_xdg_surface_opcode: u32,
  get_toplevel_opcode: u32,
  pong_opcode: u32,
  destroy_buffer_opcode: u32,

  format: u32,

  shm_socket: posix.FD,
  shm_pool: []u8,
  buffers: [2]Buffer,

  back_buffer: ^Buffer,
  front_buffer: ^Buffer,

  width: u32,
  height: u32,
  resize: bool,
  running: bool,

  //resize_callback: proc(rawptr, u32, u32),
  //ptr: rawptr,
  vk: ^VulkanContext,

  arena: ^mem.Arena,
  allocator: runtime.Allocator,

  tmp_arena: ^mem.Arena,
  tmp_allocator: runtime.Allocator,
}

init_wayland :: proc(ctx: ^WaylandContext, width: u32, height: u32, vk: ^VulkanContext, arena: ^mem.Arena, tmp_arena: ^mem.Arena) -> bool {
  ctx.arena = arena
  ctx.allocator = mem.arena_allocator(arena)
  ctx.tmp_arena = tmp_arena
  ctx.tmp_allocator = mem.arena_allocator(tmp_arena)

  ctx.vk = vk

  connect(ctx, width, height) or_return

  ctx.display_id = get_id(ctx, "wl_display", { new_callback("error", error_callback), new_callback("delete_id", delete_callback) }, wl.WAYLAND_INTERFACES[:])
  ctx.registry_id = get_id(ctx, "wl_registry", { new_callback("global", global_callback), new_callback("global_remove", global_remove_callback) }, wl.WAYLAND_INTERFACES[:])
  ctx.get_registry_opcode = get_request_opcode(ctx, "get_registry", ctx.display_id)

  write(ctx, { wl.BoundNewId(ctx.registry_id) }, ctx.display_id, ctx.get_registry_opcode)
  send(ctx) or_return

  roundtrip(ctx)
  roundtrip(ctx)

  //for ctx.running && roundtrip(ctx) {}

  return true
}

connect :: proc(ctx: ^WaylandContext, width: u32, height: u32) -> bool {
  mark := mem.begin_arena_temp_memory(ctx.tmp_arena)
  defer mem.end_arena_temp_memory(mark)

  xdg_path := os.get_env("XDG_RUNTIME_DIR", allocator = ctx.tmp_allocator)
  wayland_path := os.get_env("WAYLAND_DISPLAY", allocator = ctx.tmp_allocator)

  if len(xdg_path) == 0 || len(wayland_path) == 0 {
    return false
  }

  path := filepath.join({ xdg_path, wayland_path }, ctx.tmp_allocator)
  ctx.socket = posix.socket(.UNIX, .STREAM)

  if ctx.socket < 0 {
    return false
  }

  sockaddr := posix.sockaddr_un {
    sun_family = .UNIX,
  }

  count: uint = 0
  for c in path {
    sockaddr.sun_path[count] = u8(c)
    count += 1
  }

  if posix.connect(ctx.socket, (^posix.sockaddr)(&sockaddr), posix.socklen_t(size_of(posix.sockaddr_un))) == .FAIL do return false

  ctx.values = new_vec(wl.Argument, 40, ctx.tmp_allocator)
  ctx.objects = new_vec(InterfaceObject, 40, ctx.tmp_allocator)
  ctx.output_buffer = new_vec(u8, 4096, ctx.tmp_allocator)
  ctx.input_buffer = new_vec(u8, 4096, ctx.tmp_allocator)
  ctx.bytes = make([]u8, 1024, ctx.tmp_allocator)

  ctx.input_buffer.cap = 0
  ctx.width = width
  ctx.height = height
  ctx.running = true
  ctx.buffers = [2]Buffer {}
  ctx.front_buffer = &ctx.buffers[0]
  ctx.back_buffer = &ctx.buffers[1]

  return true
}

update :: proc(ctx: ^WaylandContext, buffer: []u8) {
  copy(ctx.shm_pool, buffer)
}

roundtrip :: proc(ctx: ^WaylandContext) -> bool {
  recv(ctx)

  for read(ctx) { }
  return ctx.running && send(ctx)
}

create_surface :: proc(ctx: ^WaylandContext) {
  ctx.surface_id = get_id(ctx, "wl_surface", { new_callback("enter", enter_callback), new_callback("leave", leave_callback), new_callback("preferred_buffer_scale", preferred_buffer_scale_callback), new_callback("preferred_buffer_transform", preferred_buffer_transform_callback) }, wl.WAYLAND_INTERFACES[:])
  ctx.surface_attach_opcode = get_request_opcode(ctx, "attach", ctx.surface_id)
  ctx.surface_commit_opcode = get_request_opcode(ctx, "commit", ctx.surface_id)

  write(ctx, { wl.BoundNewId(ctx.surface_id) }, ctx.compositor_id, ctx.create_surface_opcode)
}

create_xdg_surface :: proc(ctx: ^WaylandContext) {
  ctx.xdg_surface_id = get_id(ctx, "xdg_surface", { new_callback("configure", configure_callback) }, wl.XDG_INTERFACES[:])
  ctx.get_toplevel_opcode = get_request_opcode(ctx, "get_toplevel", ctx.xdg_surface_id)
  ctx.ack_configure_opcode = get_request_opcode(ctx, "ack_configure", ctx.xdg_surface_id)
  ctx.xdg_toplevel_id = get_id(ctx, "xdg_toplevel", { new_callback("configure", toplevel_configure_callback), new_callback("close", toplevel_close_callback), new_callback("configure_bounds", toplevel_configure_bounds_callback), new_callback("wm_capabilities", toplevel_wm_capabilities_callback) }, wl.XDG_INTERFACES[:])

  write(ctx, { wl.BoundNewId(ctx.xdg_surface_id), wl.Object(ctx.surface_id) }, ctx.xdg_wm_base_id, ctx.get_xdg_surface_opcode)
  write(ctx, { wl.BoundNewId(ctx.xdg_toplevel_id) }, ctx.xdg_surface_id, ctx.get_toplevel_opcode)

  if !create_shm_pool(ctx, 1920, 1080) do panic("Failed to create shm pool")

  write(ctx, { }, ctx.surface_id, ctx.surface_commit_opcode)
}

create_shm_pool :: proc(ctx: ^WaylandContext, max_width: u32, max_height: u32) -> bool {
  color_channels: u32 = 4

  ctx.shm_pool_id = get_id(ctx, "wl_shm_pool", {}, wl.WAYLAND_INTERFACES[:])
  ctx.create_buffer_opcode = get_request_opcode(ctx, "create_buffer", ctx.shm_pool_id)

  ctx.front_buffer.id = get_id(ctx, "wl_buffer", { new_callback("release", buffer_release_callback) }, wl.WAYLAND_INTERFACES[:])
  ctx.back_buffer.id = copy_id(ctx, ctx.front_buffer.id)

  ctx.destroy_buffer_opcode = get_request_opcode(ctx, "destroy", ctx.front_buffer.id)

  size := max_width * max_height * color_channels * 2

  name := cstring("odin_custom_wayland_client")
  ctx.shm_socket = posix.shm_open(name, { .RDWR, .EXCL, .CREAT }, { .ISVXT, .IXGRP, .IWGRP, .IXUSR })
  if ctx.shm_socket < 0 {
    return false
  }

  if posix.shm_unlink(name) == .FAIL {
    return false
  }

  if posix.ftruncate(ctx.shm_socket, posix.off_t(size)) == .FAIL {
    return false
  }

  ctx.shm_pool = ([^]u8)(posix.mmap(nil, uint(size), { .READ, .WRITE }, { .SHARED }, ctx.shm_socket, 0))[0:size]

  if ctx.shm_pool == nil do return false

  start := ctx.output_buffer.len

  write(ctx, { wl.BoundNewId(ctx.shm_pool_id), wl.Fd(-1), wl.Int(size) }, ctx.shm_id, ctx.create_shm_pool_opcode)

  if !sendmsg(ctx, posix.FD, ctx.shm_socket) do return false

  l := max_width * max_height * color_channels

  ctx.front_buffer.data = ctx.shm_pool[0:l]
  ctx.front_buffer.offset = 0
  ctx.front_buffer.released = true

  ctx.back_buffer.data = ctx.shm_pool[l:2*l]
  ctx.back_buffer.offset = l
  ctx.back_buffer.released = true

  for i in 0..<l {
    ctx.front_buffer.data[i] = 255
    ctx.back_buffer.data[i] = 255
  }

  write(ctx, { wl.BoundNewId(ctx.front_buffer.id), wl.Int(ctx.front_buffer.offset), wl.Int(ctx.width), wl.Int(ctx.height), wl.Int(color_channels * ctx.width), wl.Uint(ctx.format) }, ctx.shm_pool_id, ctx.create_buffer_opcode)
  write(ctx, { wl.BoundNewId(ctx.back_buffer.id), wl.Int(ctx.back_buffer.offset), wl.Int(ctx.width), wl.Int(ctx.height), wl.Int(color_channels * ctx.width), wl.Uint(ctx.format) }, ctx.shm_pool_id, ctx.create_buffer_opcode)

  return true
}

write :: proc(ctx: ^WaylandContext, arguments: []wl.Argument, object_id: u32, opcode: u32) {
  object := get_object(ctx, object_id)
  request := get_request(object, opcode)

  start: = ctx.output_buffer.len

  vec_append_generic(&ctx.output_buffer, u32, object_id)
  vec_append_generic(&ctx.output_buffer, u16, u16(opcode))
  total_len := vec_reserve(&ctx.output_buffer, u16)
  //fmt.println("->", object.interface.name, object_id, opcode, request.name, arguments)

  for kind, i in request.arguments {
    #partial switch kind {
    case .BoundNewId: vec_append_generic(&ctx.output_buffer, wl.BoundNewId, arguments[i].(wl.BoundNewId))
    case .Uint: vec_append_generic(&ctx.output_buffer, wl.Uint, arguments[i].(wl.Uint))
    case .Int: vec_append_generic(&ctx.output_buffer, wl.Int, arguments[i].(wl.Int))
    case .Fixed: vec_append_generic(&ctx.output_buffer, wl.Fixed, arguments[i].(wl.Fixed))
    case .Object: vec_append_generic(&ctx.output_buffer, wl.Object, arguments[i].(wl.Object))
    case .UnBoundNewId: 
      value := arguments[i].(wl.UnBoundNewId)
      l := len(value.interface)
      vec_append_generic(&ctx.output_buffer, u32, u32(l))
      vec_append_n(&ctx.output_buffer, ([]u8)(value.interface))
      vec_add_n(&ctx.output_buffer, u32(mem.align_formula(l, size_of(u32)) - l))
      vec_append_generic(&ctx.output_buffer, wl.Uint, value.version)
      vec_append_generic(&ctx.output_buffer, wl.BoundNewId, value.id)
    case .Fd:
    case:
    }
  }

  intrinsics.unaligned_store(total_len, u16(ctx.output_buffer.len - start))
}

read :: proc(ctx: ^WaylandContext) -> bool {
  ctx.values.len = 0
  bytes_len: u32 = 0

  start := ctx.input_buffer.len
  object_id := vec_read(&ctx.input_buffer, u32) or_return
  opcode := vec_read(&ctx.input_buffer, u16) or_return
  size := vec_read(&ctx.input_buffer, u16) or_return

  object := get_object(ctx, object_id)
  event := get_event(object, u32(opcode))

  for kind in event.arguments {
    #partial switch kind {
      case .Object: if !read_and_write(ctx, wl.Object) do return false
      case .Uint: if !read_and_write(ctx, wl.Uint) do return false
      case .Int: if !read_and_write(ctx, wl.Int) do return false
      case .Fixed: if !read_and_write(ctx, wl.Fixed) do return false
      case .BoundNewId: if !read_and_write(ctx, wl.BoundNewId) do return false
      case .String: if !read_and_write_collection(ctx, wl.String, &bytes_len) do return false
      case .Array: if !read_and_write_collection(ctx, wl.Array, &bytes_len) do return false
      case: return false
    }
  }

  if ctx.input_buffer.len - start != u32(size) do return false

  values := ctx.values.data[0:ctx.values.len]
  //fmt.println("<-", object.interface.name, object_id, opcode, event.name, values)
  object.callbacks[opcode](ctx, object_id, values)

  return true
}

read_and_write :: proc(ctx: ^WaylandContext, $T: typeid) -> bool {
  value := vec_read(&ctx.input_buffer, T) or_return
  vec_append(&ctx.values, value)

  return true
}

read_and_write_collection :: proc(ctx: ^WaylandContext, $T: typeid, length_ptr: ^u32) -> bool {
  start := length_ptr^

  length := vec_read(&ctx.input_buffer, u32) or_return
  bytes := vec_read_n(&ctx.input_buffer, u32(mem.align_formula(int(length), size_of(u32))))

  if bytes == nil {
    return false
  }

  copy(ctx.bytes[start:], bytes)
  vec_append(&ctx.values, T(ctx.bytes[start:length]))
  length_ptr^ += length

  return true
}

recv :: proc(ctx: ^WaylandContext) {
  count := posix.recv(ctx.socket, raw_data(ctx.input_buffer.data), 4096, { })
  ctx.input_buffer.cap = u32(count)
  ctx.input_buffer.len = 0
}

send :: proc(ctx: ^WaylandContext) -> bool {
  if ctx.output_buffer.len == 0 do return true 

  count := posix.send(ctx.socket, raw_data(ctx.output_buffer.data), uint(ctx.output_buffer.len), { })

  for ctx.output_buffer.len > 0 {
    if count < 0 {
      return false
    }

    ctx.output_buffer.len -= u32(count)
    count = posix.send(ctx.socket, raw_data(ctx.output_buffer.data[count:]), uint(ctx.output_buffer.len), { })
  }

  return true
}

sendmsg :: proc(ctx: ^WaylandContext, $T: typeid, value: T) -> bool {
  if ctx.output_buffer.len == 0 {
    return false
  }

  io := posix.iovec {
    iov_base = raw_data(ctx.output_buffer.data),
    iov_len = uint(ctx.output_buffer.len),
  }

  t_size := size_of(T)
  t_align := mem.align_formula(t_size, size_of(uint))
  cmsg_align := mem.align_formula(size_of(posix.cmsghdr), size_of(uint))

  buf := make([]u8, cmsg_align + t_align, ctx.tmp_allocator)
  defer free(raw_data(buf))

  socket_msg := posix.msghdr {
    msg_name = nil,
    msg_namelen = 0,
    msg_iov = &io,
    msg_iovlen = 1,
    msg_control = rawptr(&buf[0]),
    msg_controllen = len(buf),
    msg_flags = {},
  }

  cmsg := (^posix.cmsghdr)(socket_msg.msg_control)
  cmsg.cmsg_level = posix.SOL_SOCKET
  cmsg.cmsg_type = posix.SCM_RIGHTS
  cmsg.cmsg_len = uint(cmsg_align + t_size)

  data := (^T)(&([^]posix.cmsghdr)(cmsg)[1])
  data^ = value

  if posix.sendmsg(ctx.socket, &socket_msg, { }) < 0 {
    return false
  }

  ctx.output_buffer.len = 0

  return true
}

ctx_append :: proc(ctx: ^WaylandContext, callbacks: []CallbackConfig, interface: ^wl.Interface) {
  if len(callbacks) != len(interface.events) {
    panic("Incorrect callback length")
  }

  object: InterfaceObject
  object.interface = interface
  object.callbacks = make([]Callback, len(callbacks), ctx.allocator)

  for callback in callbacks {
    opcode := get_event_opcode(interface, callback.name)
    object.callbacks[opcode] = callback.function
  }

  vec_append(&ctx.objects, object)
}

get_object :: proc(ctx: ^WaylandContext, id: u32) -> InterfaceObject {
  return ctx.objects.data[id - 1]
}

get_id :: proc(ctx: ^WaylandContext, name: string, callbacks: []CallbackConfig, interfaces: []wl.Interface) -> u32 {
  for &inter in interfaces {
    if inter.name == name {
      defer ctx_append(ctx, callbacks, &inter)
      return ctx.objects.len + 1
    }
  }

  panic("interface id  not found")
}

copy_id :: proc(ctx: ^WaylandContext, id: u32) -> u32 {
  defer vec_append(&ctx.objects, get_object(ctx, id))
  return ctx.objects.len + 1
}

get_event :: proc(object: InterfaceObject, opcode: u32) -> ^wl.Event {
  return &object.interface.events[opcode]
}

get_request :: proc(object: InterfaceObject, opcode: u32) -> ^wl.Request {
  return &object.interface.requests[opcode]
}

get_event_opcode :: proc(interface: ^wl.Interface, name: string) -> u32 {
  for event, i in interface.events {
    if event.name == name {
      return u32(i)
    }
  }

  panic("event  opcode not found")
}

get_request_opcode :: proc(ctx: ^WaylandContext, name: string, object_id: u32) -> u32 {
  requests := get_object(ctx, object_id).interface.requests

  for request, i in requests {
    if request.name == name {
      return u32(i)
    }
  }
  
  panic("request opcode not found")
}

new_callback :: proc(name: string, callback: Callback) -> CallbackConfig {
  return CallbackConfig {
    name = name,
    function = callback,
  }
}

new_vec :: proc($T: typeid, cap: u32, allocator: runtime.Allocator) -> Vector(T) {
  vec: Vector(T)
  vec.data = make([]T, cap, allocator)
  vec.cap = cap
  vec.len = 0

  return vec
}

vec_append :: proc(vec: ^Vector($T), item: T) {
  if vec.len >= vec.cap {
    panic("Out of bounds")
  }

  vec.data[vec.len] = item
  vec.len += 1
}

vec_append_n :: proc(vec: ^Vector($T), items: []T) {
  if vec.len + u32(len(items)) > vec.cap {
    panic("Out of bounds")
  }

  defer vec.len += u32(len(items))

  copy(vec.data[vec.len:], items)
}

vec_add_n :: proc(vec: ^Vector($T), count: u32) {
  if vec.len + count > vec.cap {
    panic("Out of bounds")
  }

  vec.len += count
}

vec_read :: proc(vec: ^Vector(u8), $T: typeid) -> (T, bool) {
  value: T
  if vec.len + size_of(T) > vec.cap {
    return value, false
  }

  defer vec.len += size_of(T)
  value = intrinsics.unaligned_load((^T)(raw_data(vec.data[vec.len:])))
  return value, true
}

vec_read_n :: proc(vec: ^Vector(u8), count: u32) -> []u8 {
  if vec.len + count > vec.cap {
    return nil
  }

  defer vec.len += count
  return vec.data[vec.len:vec.len + count]
}

vec_append_generic :: proc(vec: ^Vector(u8), $T: typeid, item: T) {
  if vec.len + size_of(T) > vec.cap {
    panic("Out of bounds")
  }

  defer vec.len += size_of(T)
  intrinsics.unaligned_store((^T)(raw_data(vec.data[vec.len:])), item)
}

vec_reserve :: proc(vec: ^Vector(u8), $T: typeid) -> ^T {
  if vec.len + size_of(T) > vec.cap {
    panic("Out of bounds")
  }

  defer vec.len += size_of(T)
  return (^T)(raw_data(vec.data[vec.len:]))
}

format_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {
  format := u32(arguments[0].(wl.Uint))

  if format != 0 do return

  ctx.format = format
}

global_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {
  str := arguments[1].(wl.String)
  version := arguments[2].(wl.Uint)
  interface_name := string(str[0:len(str) - 1])

  switch interface_name {
  case "wl_shm":
    ctx.shm_id = get_id(ctx, interface_name, { new_callback("format", format_callback) } , wl.WAYLAND_INTERFACES[:])
    ctx.create_shm_pool_opcode = get_request_opcode(ctx, "create_pool", ctx.shm_id);

    write(ctx, { arguments[0], wl.UnBoundNewId{ id = wl.BoundNewId(ctx.shm_id), interface = str, version = version }}, ctx.registry_id, ctx.registry_bind_opcode)
  case "xdg_wm_base":
    ctx.xdg_wm_base_id = get_id(ctx, interface_name, { new_callback("ping", ping_callback) }, wl.XDG_INTERFACES[:])
    ctx.pong_opcode = get_request_opcode(ctx, "pong", ctx.xdg_wm_base_id)
    ctx.get_xdg_surface_opcode = get_request_opcode(ctx, "get_xdg_surface", ctx.xdg_wm_base_id)

    write(ctx, { arguments[0], wl.UnBoundNewId{ id = wl.BoundNewId(ctx.xdg_wm_base_id), interface = str, version = version }}, ctx.registry_id, ctx.registry_bind_opcode)
    create_xdg_surface(ctx)
  case "wl_compositor":
    ctx.compositor_id = get_id( ctx, interface_name, { } , wl.WAYLAND_INTERFACES[:])
    ctx.create_surface_opcode = get_request_opcode(ctx, "create_surface", ctx.compositor_id)

    write(ctx, { arguments[0], wl.UnBoundNewId{ id = wl.BoundNewId(ctx.compositor_id), interface = str, version = version }}, ctx.registry_id, ctx.registry_bind_opcode)
    create_surface(ctx)
  }
}

global_remove_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {
}

configure_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {
  if !ctx.front_buffer.released {
    write(ctx, { arguments[0] }, id, ctx.ack_configure_opcode)
    return
  }

  if !ctx.front_buffer.update {
    defer ctx.front_buffer.update = true

    write(ctx, {}, ctx.front_buffer.id, ctx.destroy_buffer_opcode)

    write(ctx, { wl.BoundNewId(ctx.front_buffer.id), wl.Int(ctx.front_buffer.offset), wl.Int(ctx.width), wl.Int(ctx.height), wl.Int(4 * ctx.width), wl.Uint(ctx.format) }, ctx.shm_pool_id, ctx.create_buffer_opcode)

    write_image(ctx.vk, ctx.width, ctx.height, ctx.front_buffer.data)
  }

  ctx.front_buffer.released = false

  write(ctx, { arguments[0] }, id, ctx.ack_configure_opcode)
  write(ctx, { wl.Object(ctx.front_buffer.id), wl.Int(0), wl.Int(0) }, ctx.surface_id, ctx.surface_attach_opcode)
  write(ctx, { }, ctx.surface_id, ctx.surface_commit_opcode)

  ctx.front_buffer, ctx.back_buffer = ctx.back_buffer, ctx.front_buffer
}

ping_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {
  write(ctx, { arguments[0] }, ctx.xdg_wm_base_id, ctx.pong_opcode)
}

toplevel_configure_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {
  width := u32(arguments[0].(wl.Int))
  height := u32(arguments[1].(wl.Int))

  if width == 0 || height == 0 do return
  if width == ctx.width && height == ctx.height do return

  ctx.width = width
  ctx.height = height

  ctx.front_buffer.update = false
  ctx.back_buffer.update = false

  if !resize_renderer(ctx.vk, width, height) do panic("failed to resize renderer")

  ctx.resize = true
}

toplevel_close_callback :: proc(ctx: ^WaylandContext, id: u32, arugments: []wl.Argument) {
  ctx.running = false
}

toplevel_configure_bounds_callback :: proc(ctx: ^WaylandContext, id: u32, arugments: []wl.Argument) {
}

toplevel_wm_capabilities_callback :: proc(ctx: ^WaylandContext, id: u32, arugments: []wl.Argument) {
}

buffer_release_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {
  ctx.front_buffer.released = true
}

enter_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {
}

leave_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {
}

preferred_buffer_scale_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {
}

preferred_buffer_transform_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {
}

delete_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {
}

error_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {
  fmt.println("error:", string(arguments[2].(wl.String)))
}

