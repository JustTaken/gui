package main

import wl "wayland"
import "core:os"
import "core:mem"
import "core:sys/posix"
import "core:path/filepath"
import "base:intrinsics"
import "base:runtime"

Vector :: struct(T: typeid) {
  data: []T,
  cap: u32,
  len: u32,
}

Callback :: proc(^Connection, u32, []wl.Argument)
CallbackConfig :: struct {
  name: string,
  function: Callback,
}

InterfaceObject :: struct {
  interface: ^wl.Interface,
  callbacks: []Callback,
}

Connection :: struct {
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
  buffer_id: u32,

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
  buffer: []u8,

  width: u32,
  height: u32,
  resize: bool,
  running: bool,

  arena: ^mem.Arena,
  allocator: runtime.Allocator,

  tmp_arena: ^mem.Arena,
  tmp_allocator: runtime.Allocator,
}

connect :: proc(connection: ^Connection, width: u32, height: u32, allocator: runtime.Allocator) -> bool {
  xdg_path := os.get_env("XDG_RUNTIME_DIR", allocator = allocator)
  wayland_path := os.get_env("WAYLAND_DISPLAY", allocator = allocator)

  if len(xdg_path) == 0 || len(wayland_path) == 0 {
    return false
  }

  path := filepath.join({ xdg_path, wayland_path }, allocator)
  connection.socket = posix.socket(.UNIX, .STREAM)

  if connection.socket < 0 {
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

  if posix.connect(connection.socket, (^posix.sockaddr)(&sockaddr), posix.socklen_t(size_of(posix.sockaddr_un))) == .FAIL do return false

  connection.values = new_vec(wl.Argument, 40, allocator)
  connection.objects = new_vec(InterfaceObject, 40, allocator)
  connection.output_buffer = new_vec(u8, 4096, allocator)
  connection.input_buffer = new_vec(u8, 4096, allocator)
  connection.bytes = make([]u8, 1024, allocator)

  connection.input_buffer.cap = 0
  connection.width = width
  connection.height = height
  connection.running = true

  return true
}

init_wayland :: proc(arena: ^mem.Arena, tmp_arena: ^mem.Arena) -> bool {
  connection: Connection

  connection.arena = arena
  connection.allocator = mem.arena_allocator(arena)
  connection.tmp_arena = tmp_arena
  connection.tmp_allocator = mem.arena_allocator(tmp_arena)

  connect(&connection, 600, 400, context.allocator) or_return

  connection.display_id = get_id(&connection, "wl_display", { new_callback("error", error_callback), new_callback("delete_id", delete_callback) }, wl.WAYLAND_INTERFACES[:])
  connection.registry_id = get_id(&connection, "wl_registry", { new_callback("global", global_callback), new_callback("global_remove", global_remove_callback) }, wl.WAYLAND_INTERFACES[:])
  connection.get_registry_opcode = get_request_opcode(&connection, "get_registry", connection.display_id)

  write(&connection, { wl.BoundNewId(connection.registry_id) }, connection.display_id, connection.get_registry_opcode)
  send(&connection) or_return

  roundtrip(&connection)
  roundtrip(&connection)

  for connection.running && roundtrip(&connection) {}

  return true
}

roundtrip :: proc(connection: ^Connection) -> bool {
  recv(connection)

  for read(connection) { }
  return send(connection)
}

commit :: proc(connection: ^Connection) {
  write(connection, { }, connection.surface_id, connection.surface_commit_opcode)
}

create_surface :: proc(connection: ^Connection) {
  connection.surface_id = get_id(connection, "wl_surface", { new_callback("enter", enter_callback), new_callback("leave", leave_callback), new_callback("preferred_buffer_scale", preferred_buffer_scale_callback), new_callback("preferred_buffer_transform", preferred_buffer_transform_callback) }, wl.WAYLAND_INTERFACES[:])
  connection.surface_attach_opcode = get_request_opcode(connection, "attach", connection.surface_id)
  connection.surface_commit_opcode = get_request_opcode(connection, "commit", connection.surface_id)

  write(connection, { wl.BoundNewId(connection.surface_id) }, connection.compositor_id, connection.create_surface_opcode)
}

create_xdg_surface :: proc(connection: ^Connection) {
  connection.xdg_surface_id = get_id(connection, "xdg_surface", { new_callback("configure", configure_callback) }, wl.XDG_INTERFACES[:])
  connection.get_toplevel_opcode = get_request_opcode(connection, "get_toplevel", connection.xdg_surface_id)
  connection.ack_configure_opcode = get_request_opcode(connection, "ack_configure", connection.xdg_surface_id)
  connection.xdg_toplevel_id = get_id(connection, "xdg_toplevel", { new_callback("configure", toplevel_configure_callback), new_callback("close", toplevel_close_callback), new_callback("configure_bounds", toplevel_configure_bounds_callback), new_callback("wm_capabilities", toplevel_wm_capabilities_callback) }, wl.XDG_INTERFACES[:])

  write(connection, { wl.BoundNewId(connection.xdg_surface_id), wl.Object(connection.surface_id) }, connection.xdg_wm_base_id, connection.get_xdg_surface_opcode)
  write(connection, { wl.BoundNewId(connection.xdg_toplevel_id) }, connection.xdg_surface_id, connection.get_toplevel_opcode)

  if !create_shm_pool(connection, 1920, 1080) do panic("Failed to create shm pool")

  commit(connection)
}

create_shm_pool :: proc(connection: ^Connection, max_width: u32, max_height: u32) -> bool {
  color_channels: u32 = 4

  connection.shm_pool_id = get_id(connection, "wl_shm_pool", {}, wl.WAYLAND_INTERFACES[:])
  connection.create_buffer_opcode = get_request_opcode(connection, "create_buffer", connection.shm_pool_id)

  connection.buffer_id = get_id(connection, "wl_buffer", { new_callback("release", buffer_release_callback) }, wl.WAYLAND_INTERFACES[:])
  connection.destroy_buffer_opcode = get_request_opcode(connection, "destroy", connection.buffer_id)

  size := max_width * max_height * color_channels

  name := cstring("odin_custom_wayland_client")
  connection.shm_socket = posix.shm_open(name, { .RDWR, .EXCL, .CREAT }, { .ISVXT, .IXGRP, .IWGRP, .IXUSR })
  if connection.shm_socket < 0 {
    return false
  }

  if posix.shm_unlink(name) == .FAIL {
    return false
  }

  if posix.ftruncate(connection.shm_socket, posix.off_t(size)) == .FAIL {
    return false
  }

  connection.shm_pool = ([^]u8)(posix.mmap(nil, uint(size), { .READ, .WRITE }, { .SHARED }, connection.shm_socket, 0))[0:size]

  start := connection.output_buffer.len

  write(connection, { wl.BoundNewId(connection.shm_pool_id), wl.Fd(-1), wl.Int(size) }, connection.shm_id, connection.create_shm_pool_opcode)

  if !sendmsg(connection, posix.FD, connection.shm_socket) do return false

  write(connection, { wl.BoundNewId(connection.buffer_id), wl.Int(0), wl.Int(connection.width), wl.Int(connection.height), wl.Int(color_channels * connection.width), wl.Uint(connection.format) }, connection.shm_pool_id, connection.create_buffer_opcode)

  l := connection.width * connection.height * color_channels
  connection.buffer = connection.shm_pool[0:l]
  for i in 0..<l {
    connection.buffer[i] = 255
  }

  return true
}

write :: proc(connection: ^Connection, arguments: []wl.Argument, object_id: u32, opcode: u32) {
  object := get_object(connection, object_id)
  request := get_request(object, opcode)

  start: = connection.output_buffer.len

  vec_append_generic(&connection.output_buffer, u32, object_id)
  vec_append_generic(&connection.output_buffer, u16, u16(opcode))
  total_len := vec_reserve(&connection.output_buffer, u16)

  for kind, i in request.arguments {
    #partial switch kind {
    case .BoundNewId: vec_append_generic(&connection.output_buffer, wl.BoundNewId, arguments[i].(wl.BoundNewId))
    case .Uint: vec_append_generic(&connection.output_buffer, wl.Uint, arguments[i].(wl.Uint))
    case .Int: vec_append_generic(&connection.output_buffer, wl.Int, arguments[i].(wl.Int))
    case .Fixed: vec_append_generic(&connection.output_buffer, wl.Fixed, arguments[i].(wl.Fixed))
    case .Object: vec_append_generic(&connection.output_buffer, wl.Object, arguments[i].(wl.Object))
    case .UnBoundNewId: 
      value := arguments[i].(wl.UnBoundNewId)
      l := len(value.interface)
      vec_append_generic(&connection.output_buffer, u32, u32(l))
      vec_append_n(&connection.output_buffer, ([]u8)(value.interface))
      vec_add_n(&connection.output_buffer, u32(mem.align_formula(l, size_of(u32)) - l))
      vec_append_generic(&connection.output_buffer, wl.Uint, value.version)
      vec_append_generic(&connection.output_buffer, wl.BoundNewId, value.id)
    case .Fd:
    case:
    }
  }

  intrinsics.unaligned_store(total_len, u16(connection.output_buffer.len - start))
}

read :: proc(connection: ^Connection) -> bool {
  connection.values.len = 0
  bytes_len: u32 = 0

  start := connection.input_buffer.len
  object_id := vec_read(&connection.input_buffer, u32) or_return
  opcode := vec_read(&connection.input_buffer, u16) or_return
  size := vec_read(&connection.input_buffer, u16) or_return

  object := get_object(connection, object_id)
  event := get_event(object, u32(opcode))

  for kind in event.arguments {
    #partial switch kind {
      case .Object: if !read_and_write(connection, wl.Object) do return false
      case .Uint: if !read_and_write(connection, wl.Uint) do return false
      case .Int: if !read_and_write(connection, wl.Int) do return false
      case .Fixed: if !read_and_write(connection, wl.Fixed) do return false
      case .BoundNewId: if !read_and_write(connection, wl.BoundNewId) do return false
      case .String: if !read_and_write_collection(connection, wl.String, &bytes_len) do return false
      case .Array: if !read_and_write_collection(connection, wl.Array, &bytes_len) do return false
      case: return false
    }
  }

  if connection.input_buffer.len - start != u32(size) do return false

  values := connection.values.data[0:connection.values.len]
  object.callbacks[opcode](connection, object_id, values)

  return true
}

read_and_write :: proc(connection: ^Connection, $T: typeid) -> bool {
  value := vec_read(&connection.input_buffer, T) or_return
  vec_append(&connection.values, value)

  return true
}

read_and_write_collection :: proc(connection: ^Connection, $T: typeid, length_ptr: ^u32) -> bool {
  start := length_ptr^

  length := vec_read(&connection.input_buffer, u32) or_return
  bytes := vec_read_n(&connection.input_buffer, u32(mem.align_formula(int(length), size_of(u32))))

  if bytes == nil {
    return false
  }

  copy(connection.bytes[start:], bytes)
  vec_append(&connection.values, T(connection.bytes[start:length]))
  length_ptr^ += length

  return true
}

recv :: proc(connection: ^Connection) {
  count := posix.recv(connection.socket, raw_data(connection.input_buffer.data), 4096, { })
  connection.input_buffer.cap = u32(count)
  connection.input_buffer.len = 0
}

send :: proc(connection: ^Connection) -> bool {
  if connection.output_buffer.len == 0 do return true 

  count := posix.send(connection.socket, raw_data(connection.output_buffer.data), uint(connection.output_buffer.len), { })

  for connection.output_buffer.len > 0 {
    if count < 0 {
      return false
    }

    connection.output_buffer.len -= u32(count)
    count = posix.send(connection.socket, raw_data(connection.output_buffer.data[count:]), uint(connection.output_buffer.len), { })
  }

  return true
}

sendmsg :: proc(connection: ^Connection, $T: typeid, value: T) -> bool {
  if connection.output_buffer.len == 0 {
    return false
  }

  io := posix.iovec {
    iov_base = raw_data(connection.output_buffer.data),
    iov_len = uint(connection.output_buffer.len),
  }

  t_size := size_of(T)
  t_align := mem.align_formula(t_size, size_of(uint))
  cmsg_align := mem.align_formula(size_of(posix.cmsghdr), size_of(uint))

  buf := make([]u8, cmsg_align + t_align, connection.tmp_allocator)
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

  if posix.sendmsg(connection.socket, &socket_msg, { }) < 0 {
    return false
  }

  connection.output_buffer.len = 0

  return true
}

connection_append :: proc(connection: ^Connection, callbacks: []CallbackConfig, interface: ^wl.Interface) {
  if len(callbacks) != len(interface.events) {
    panic("Incorrect callback length")
  }

  object: InterfaceObject
  object.interface = interface
  object.callbacks = make([]Callback, len(callbacks), connection.allocator)

  for callback in callbacks {
    opcode := get_event_opcode(interface, callback.name)
    object.callbacks[opcode] = callback.function
  }

  vec_append(&connection.objects, object)
}

get_object :: proc(connection: ^Connection, id: u32) -> InterfaceObject {
  return connection.objects.data[id - 1]
}

get_id :: proc(connection: ^Connection, name: string, callbacks: []CallbackConfig, interfaces: []wl.Interface) -> u32 {
  for &inter in interfaces {
    if inter.name == name {
      defer connection_append(connection, callbacks, &inter)
      return connection.objects.len + 1
    }
  }

  panic("interface id  not found")
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

get_request_opcode :: proc(connection: ^Connection, name: string, object_id: u32) -> u32 {
  requests := get_object(connection, object_id).interface.requests

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

format_callback :: proc(connection: ^Connection, id: u32, arguments: []wl.Argument) {
  format := u32(arguments[0].(wl.Uint))

  if format != 0 do return

  connection.format = format
}

global_callback :: proc(connection: ^Connection, id: u32, arguments: []wl.Argument) {
  str := arguments[1].(wl.String)
  version := arguments[2].(wl.Uint)
  interface_name := string(str[0:len(str) - 1])

  switch interface_name {
  case "wl_shm":
    connection.shm_id = get_id(connection, interface_name, { new_callback("format", format_callback) } , wl.WAYLAND_INTERFACES[:])
    connection.create_shm_pool_opcode = get_request_opcode(connection, "create_pool", connection.shm_id);

    write(connection, { arguments[0], wl.UnBoundNewId{ id = wl.BoundNewId(connection.shm_id), interface = str, version = version }}, connection.registry_id, connection.registry_bind_opcode)
  case "xdg_wm_base":
    connection.xdg_wm_base_id = get_id(connection, interface_name, { new_callback("ping", ping_callback) }, wl.XDG_INTERFACES[:])
    connection.pong_opcode = get_request_opcode(connection, "pong", connection.xdg_wm_base_id)
    connection.get_xdg_surface_opcode = get_request_opcode(connection, "get_xdg_surface", connection.xdg_wm_base_id)

    write(connection, { arguments[0], wl.UnBoundNewId{ id = wl.BoundNewId(connection.xdg_wm_base_id), interface = str, version = version }}, connection.registry_id, connection.registry_bind_opcode)
    create_xdg_surface(connection)
  case "wl_compositor":
    connection.compositor_id = get_id( connection, interface_name, { } , wl.WAYLAND_INTERFACES[:])
    connection.create_surface_opcode = get_request_opcode(connection, "create_surface", connection.compositor_id)

    write(connection, { arguments[0], wl.UnBoundNewId{ id = wl.BoundNewId(connection.compositor_id), interface = str, version = version }}, connection.registry_id, connection.registry_bind_opcode)
    create_surface(connection)
  }
}

global_remove_callback :: proc(connection: ^Connection, id: u32, arguments: []wl.Argument) {
}

configure_callback :: proc(connection: ^Connection, id: u32, arguments: []wl.Argument) {
  write(connection, { arguments[0] }, id, connection.ack_configure_opcode)
  write(connection, { wl.Object(connection.buffer_id), wl.Int(0), wl.Int(0) }, connection.surface_id, connection.surface_attach_opcode)
  commit(connection)
}

ping_callback :: proc(connection: ^Connection, id: u32, arguments: []wl.Argument) {
  write(connection, { arguments[0] }, connection.xdg_wm_base_id, connection.pong_opcode)
}

toplevel_configure_callback :: proc(connection: ^Connection, id: u32, arguments: []wl.Argument) {
  width := u32(arguments[0].(wl.Int))
  height := u32(arguments[1].(wl.Int))

  if width == 0 || height == 0 do return
  if width == connection.width && height == connection.height do return

  connection.width = width
  connection.height = height
  connection.resize = true
}

toplevel_close_callback :: proc(connection: ^Connection, id: u32, arugments: []wl.Argument) {
  connection.running = false
}

toplevel_configure_bounds_callback :: proc(connection: ^Connection, id: u32, arugments: []wl.Argument) {
}

toplevel_wm_capabilities_callback :: proc(connection: ^Connection, id: u32, arugments: []wl.Argument) {
}

buffer_release_callback :: proc(connection: ^Connection, id: u32, arguments: []wl.Argument) {
  if connection.resize {
    write(connection, {}, id, connection.destroy_buffer_opcode)
    write(connection, { wl.BoundNewId(id), wl.Int(0), wl.Int(connection.width), wl.Int(connection.height), wl.Int(4 * connection.width), wl.Uint(connection.format) }, connection.shm_pool_id, connection.create_buffer_opcode)
 
    l := connection.width * connection.height * 4
    connection.buffer = connection.shm_pool[0:l]
    for i in 0..<l {
      connection.buffer[i] = 255
    }
   
    connection.resize = false
    write(connection, { wl.Object(connection.buffer_id), wl.Int(0), wl.Int(0) }, connection.surface_id, connection.surface_attach_opcode)
    commit(connection)
  }
}

enter_callback :: proc(connection: ^Connection, id: u32, arguments: []wl.Argument) {
}

leave_callback :: proc(connection: ^Connection, id: u32, arguments: []wl.Argument) {
}

preferred_buffer_scale_callback :: proc(connection: ^Connection, id: u32, arguments: []wl.Argument) {
}

preferred_buffer_transform_callback :: proc(connection: ^Connection, id: u32, arguments: []wl.Argument) {
}

delete_callback :: proc(connection: ^Connection, id: u32, arguments: []wl.Argument) {
}

error_callback :: proc(connection: ^Connection, id: u32, arguments: []wl.Argument) {
}

