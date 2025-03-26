package main

import "core:os" 
import "core:sys/posix"
import "core:fmt"
import "core:path/filepath" 
import "base:intrinsics"
import "core:mem"
import "core:time"
import wl "wayland"

main :: proc() {
  arena: mem.Arena
  bytes := make([]u8, 1024 * 1024 * 1)
  mem.arena_init(&arena, bytes)
  context.allocator = mem.arena_allocator(&arena)

  connection, ok := connect(context.allocator)

  if !ok {
    fmt.println("Failed to open wayland connection")
    return
  }

  display_id := get_id(&connection, "wl_display", wl.WAYLAND_INTERFACES[:])
  registry_id := get_id(&connection, "wl_registry", wl.WAYLAND_INTERFACES[:])
  get_registry_opcode := get_request_opcode(&connection, "get_registry", display_id)

  write(&connection, { wl.BoundNewId(registry_id) }, display_id, get_registry_opcode)
  send(&connection)
  recv(&connection)

  for {
    arguments := read(&connection);

    if arguments == nil {
      break
    }
  }
}

Vector :: struct(T: typeid) {
  data: []T,
  cap: u32,
  len: u32,
}

new_vec :: proc($T: typeid, cap: u32, allocator := context.allocator) -> Vector(T) {
  vec: Vector(T)
  vec.data = make([]T, cap)
  vec.cap = cap
  vec.len = 0

  return vec
}

vec_append :: proc(vec: ^Vector($T), item: T) {
  vec.data[vec.len] = item
  vec.len += 1
}

vec_read :: proc(vec: ^Vector(u8), $T: typeid) -> (T, bool) {
  value: T
  if vec.len >= vec.cap {
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
  defer vec.len += size_of(T)
  intrinsics.unaligned_store((^T)(raw_data(vec.data[vec.len:])), item)
}

vec_reserve :: proc(vec: ^Vector(u8), $T: typeid) -> ^T {
  defer vec.len += size_of(T)
  return (^T)(raw_data(vec.data[vec.len:]))
}

Connection :: struct {
  socket: posix.FD,
  objects: Vector(^wl.Interface),
  output_buffer: Vector(u8),
  input_buffer: Vector(u8),
  values: Vector(wl.Argument),
  bytes: []u8,
}

connect :: proc(allocator := context.allocator) -> (Connection, bool) {
  connection: Connection

  xdg_path := os.get_env("XDG_RUNTIME_DIR", allocator = allocator)
  wayland_path := os.get_env("WAYLAND_DISPLAY", allocator = allocator)

  if len(xdg_path) == 0 || len(wayland_path) == 0 {
    fmt.println("Failed to get env variables")
    return connection, false
  }

  path := filepath.join({ xdg_path, wayland_path }, allocator)
  connection.socket = posix.socket(.UNIX, .STREAM)

  if connection.socket < 0 {
    fmt.println("Failed to create unix socket")
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
    fmt.println("Failed to connect to compositor socket")
    return connection, false
  }

  err: mem.Allocator_Error

  connection.values = new_vec(wl.Argument, 40)
  connection.objects = new_vec(^wl.Interface, 40)
  connection.output_buffer = new_vec(u8, 4096)
  connection.input_buffer = new_vec(u8, 4096)
  connection.bytes = make([]u8, 1024)

  connection.input_buffer.cap = 0

  return connection, true
}

write :: proc(connection: ^Connection, arguments: []wl.Argument, object_id: u32, opcode: u32) {
  object := get_object(connection, object_id)
  request := &object.requests[opcode]

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
    case:
      fmt.println("getting non registred value type")
    }
  }

  intrinsics.unaligned_store(total_len, u16(connection.output_buffer.len - start))
}

read :: proc(connection: ^Connection) -> []wl.Argument {
  object_id: u32
  opcode: u16
  size: u16
  ok: bool

  connection.values.len = 0
  bytes_len: u32 = 0

  start := connection.input_buffer.len
  object_id, ok = vec_read(&connection.input_buffer, u32)
  opcode, ok = vec_read(&connection.input_buffer, u16)
  size, ok = vec_read(&connection.input_buffer, u16)

  if !ok {
    return nil
  }

  object := get_object(connection, object_id)
  event := &object.events[opcode]

  for kind in event.arguments {
    #partial switch kind {
      case .Object: if !read_and_write(connection, wl.Object) do return nil
      case .Uint: if !read_and_write(connection, wl.Uint) do return nil
      case .Int: if !read_and_write(connection, wl.Int) do return nil
      case .Fixed: if !read_and_write(connection, wl.Fixed) do return nil
      case .BoundNewId: if !read_and_write(connection, wl.BoundNewId) do return nil
      case .String: if !read_and_write_collection(connection, wl.String, &bytes_len) do return nil
      case .Array: if !read_and_write_collection(connection, wl.Array, &bytes_len) do return nil
      case: return nil
    }
  }

  if connection.input_buffer.len - start != u32(size) {
    fmt.println("size read and size announced does not match")
    return nil
  }

  if object_id == 1 && opcode == 0 {
    fmt.println("error: code", connection.values.data[1], string(connection.values.data[2].(wl.String)))
    return nil
  } else if object_id == 2 && opcode == 0 {
    fmt.println("registry global on: name", connection.values.data[0].(wl.Uint), "interface:", string(connection.values.data[1].(wl.String)), "version:", connection.values.data[2].(wl.Uint))
  }

  return connection.values.data[0:connection.values.len]
}

read_and_write :: proc(connection: ^Connection, $T: typeid) -> bool {
  value: T
  ok: bool
  value, ok = vec_read(&connection.input_buffer, T)

  if ok {
    vec_append(&connection.values, value)
  }

  return ok
}

read_and_write_collection :: proc(connection: ^Connection, $T: typeid, length_ptr: ^u32) -> bool {
  start := length_ptr^
  length: u32
  bytes: []u8
  ok: bool
  length, ok = vec_read(&connection.input_buffer, u32)
  bytes = vec_read_n(&connection.input_buffer, u32(mem.align_formula(int(length), size_of(u32))))

  if !ok || bytes == nil {
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

send :: proc(connection: ^Connection) {
  fmt.println("send:", connection.output_buffer.data[0:connection.output_buffer.len])

  count := posix.send(connection.socket, raw_data(connection.output_buffer.data), uint(connection.output_buffer.len), { })

  if u32(count) != connection.output_buffer.len {
    fmt.println("Failed to send every information into the socket, total:", count)
  }

  connection.output_buffer.len = 0
}

connection_append :: proc(connection: ^Connection, interface: ^wl.Interface) {
  vec_append(&connection.objects, interface)
}

get_object :: proc(connection: ^Connection, id: u32) -> ^wl.Interface {
  return connection.objects.data[id - 1]
}

get_id :: proc(connection: ^Connection, name: string, interfaces: []wl.Interface) -> u32 {
  for &inter in interfaces {
    if inter.name == name {
      defer connection_append(connection, &inter)
      return connection.objects.len + 1
    }
  }

  return 0
}

get_request_opcode :: proc(connection: ^Connection, name: string, object_id: u32) -> u32 {
  object := get_object(connection, object_id)

  for request, i in object.requests {
    if request.name == name {
      return u32(i)
    }
  }

  return 0
}

