package protocol

import "core:os"
import "core:mem"
import "core:sys/posix"
import "core:path/filepath"
import "base:intrinsics"

Vector :: struct(T: typeid) {
  data: []T,
  cap: u32,
  len: u32,
}

Callback :: proc(^Connection, u32, []Argument)
CallbackConfig :: struct {
  name: string,
  function: Callback,
}

InterfaceObject :: struct {
  interface: ^Interface,
  callbacks: []Callback,
}

Connection :: struct {
  socket: posix.FD,
  objects: Vector(InterfaceObject),
  output_buffer: Vector(u8),
  input_buffer: Vector(u8),
  values: Vector(Argument),
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
}

connect :: proc(width: u32, height: u32, allocator := context.allocator) -> (Connection, bool) {
  connection: Connection

  xdg_path := os.get_env("XDG_RUNTIME_DIR", allocator = allocator)
  wayland_path := os.get_env("WAYLAND_DISPLAY", allocator = allocator)

  if len(xdg_path) == 0 || len(wayland_path) == 0 {
    return connection, false
  }

  path := filepath.join({ xdg_path, wayland_path }, allocator)
  connection.socket = posix.socket(.UNIX, .STREAM)

  if connection.socket < 0 {
    return connection, false
  }

  sockaddr := posix.sockaddr_un {
    sun_family = .UNIX,
  }

  count: uint = 0
  for c in path {
    sockaddr.sun_path[count] = u8(c)
    count += 1
  }

  result := posix.connect(connection.socket, (^posix.sockaddr)(&sockaddr), posix.socklen_t(size_of(posix.sockaddr_un)))

  if result == .FAIL {
    return connection, false
  }

  err: mem.Allocator_Error

  connection.values = new_vec(Argument, 40)
  connection.objects = new_vec(InterfaceObject, 40)
  connection.output_buffer = new_vec(u8, 4096)
  connection.input_buffer = new_vec(u8, 4096)
  connection.bytes = make([]u8, 1024)

  connection.input_buffer.cap = 0
  connection.width = width
  connection.height = height
  connection.running = true

  return connection, true
}

create_shm_pool :: proc(connection: ^Connection, size: u32) -> bool {
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

  write(connection, { BoundNewId(connection.shm_pool_id), Fd(-1), Int(size) }, connection.shm_id, connection.create_shm_pool_opcode)

  return sendmsg(connection, posix.FD, connection.shm_socket)
}

write :: proc(connection: ^Connection, arguments: []Argument, object_id: u32, opcode: u32) {
  object := get_object(connection, object_id)
  request := get_request(object, opcode)

  start: = connection.output_buffer.len

  vec_append_generic(&connection.output_buffer, u32, object_id)
  vec_append_generic(&connection.output_buffer, u16, u16(opcode))
  total_len := vec_reserve(&connection.output_buffer, u16)

  for kind, i in request.arguments {
    #partial switch kind {
    case .BoundNewId: vec_append_generic(&connection.output_buffer, BoundNewId, arguments[i].(BoundNewId))
    case .Uint: vec_append_generic(&connection.output_buffer, Uint, arguments[i].(Uint))
    case .Int: vec_append_generic(&connection.output_buffer, Int, arguments[i].(Int))
    case .Fixed: vec_append_generic(&connection.output_buffer, Fixed, arguments[i].(Fixed))
    case .Object: vec_append_generic(&connection.output_buffer, Object, arguments[i].(Object))
    case .UnBoundNewId: 
      value := arguments[i].(UnBoundNewId)
      l := len(value.interface)
      vec_append_generic(&connection.output_buffer, u32, u32(l))
      vec_append_n(&connection.output_buffer, ([]u8)(value.interface))
      vec_add_n(&connection.output_buffer, u32(mem.align_formula(l, size_of(u32)) - l))
      vec_append_generic(&connection.output_buffer, Uint, value.version)
      vec_append_generic(&connection.output_buffer, BoundNewId, value.id)
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
      case .Object: if !read_and_write(connection, Object) do return false
      case .Uint: if !read_and_write(connection, Uint) do return false
      case .Int: if !read_and_write(connection, Int) do return false
      case .Fixed: if !read_and_write(connection, Fixed) do return false
      case .BoundNewId: if !read_and_write(connection, BoundNewId) do return false
      case .String: if !read_and_write_collection(connection, String, &bytes_len) do return false
      case .Array: if !read_and_write_collection(connection, Array, &bytes_len) do return false
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

  buf := make([]u8, cmsg_align + t_align)
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

connection_append :: proc(connection: ^Connection, callbacks: []CallbackConfig, interface: ^Interface, allocator := context.allocator) {
  if len(callbacks) != len(interface.events) {
    panic("Incorrect callback length")
  }

  object: InterfaceObject
  object.interface = interface
  object.callbacks = make([]Callback, len(callbacks), allocator)

  for callback in callbacks {
    opcode := get_event_opcode(interface, callback.name)
    object.callbacks[opcode] = callback.function
  }

  vec_append(&connection.objects, object)
}

get_object :: proc(connection: ^Connection, id: u32) -> InterfaceObject {
  return connection.objects.data[id - 1]
}

get_id :: proc(connection: ^Connection, name: string, callbacks: []CallbackConfig, interfaces: []Interface, allocator := context.allocator) -> u32 {
  for &inter in interfaces {
    if inter.name == name {
      defer connection_append(connection, callbacks, &inter, allocator)
      return connection.objects.len + 1
    }
  }

  panic("interface id  not found")
}

get_event :: proc(object: InterfaceObject, opcode: u32) -> ^Event {
  return &object.interface.events[opcode]
}

get_request :: proc(object: InterfaceObject, opcode: u32) -> ^Request {
  return &object.interface.requests[opcode]
}

get_event_opcode :: proc(interface: ^Interface, name: string) -> u32 {
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

new_vec :: proc($T: typeid, cap: u32, allocator := context.allocator) -> Vector(T) {
  vec: Vector(T)
  vec.data = make([]T, cap)
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
