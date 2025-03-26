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

  connection.display_id = get_id(&connection, "wl_display", { callback_config("error", error_callback), callback_config("delete_id", null_callback) }, wl.WAYLAND_INTERFACES[:], context.allocator)
  connection.registry_id = get_id(&connection, "wl_registry", { callback_config("global", global_callback), callback_config("global_remove", null_callback) }, wl.WAYLAND_INTERFACES[:], context.allocator)
  connection.get_registry_opcode = get_request_opcode(&connection, "get_registry", connection.display_id)

  write(&connection, { wl.BoundNewId(connection.registry_id) }, connection.display_id, connection.get_registry_opcode)
  send(&connection)

  for {
    success := read(&connection);

    if !success {
      send(&connection)
      recv(&connection)
    }
  }
}

CallbackConfig :: struct {
  name: string,
  function: Callback,
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

Callback :: proc(^Connection, []wl.Argument)
Object :: struct {
  interface: ^wl.Interface,
  callbacks: []Callback,
}

Connection :: struct {
  socket: posix.FD,
  objects: Vector(Object),
  output_buffer: Vector(u8),
  input_buffer: Vector(u8),
  values: Vector(wl.Argument),
  bytes: []u8,

  display_id: u32,
  registry_id: u32,
  shm_id: u32,
  compositor_id: u32,

  get_registry_opcode: u32,
  registry_bind_opcode: u32,
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
  connection.objects = new_vec(Object, 40)
  connection.output_buffer = new_vec(u8, 4096)
  connection.input_buffer = new_vec(u8, 4096)
  connection.bytes = make([]u8, 1024)

  connection.input_buffer.cap = 0
  connection.display_id = 0
  connection.registry_id = 0
  connection.shm_id = 0
  connection.compositor_id = 0

  connection.get_registry_opcode = 0
  connection.registry_bind_opcode = 0

  return connection, true
}

write :: proc(connection: ^Connection, arguments: []wl.Argument, object_id: u32, opcode: u32) {
  object := get_object(connection, object_id)
  request := get_request(object, opcode)

  start: = connection.output_buffer.len

  vec_append_generic(&connection.output_buffer, u32, object_id)
  vec_append_generic(&connection.output_buffer, u16, u16(opcode))
  total_len := vec_reserve(&connection.output_buffer, u16)

  fmt.println("writing", object_id, opcode, arguments)

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
    case:
      fmt.println("getting non registred value type")
    }
  }

  intrinsics.unaligned_store(total_len, u16(connection.output_buffer.len - start))
}

read :: proc(connection: ^Connection) -> bool {
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
    return false
  }

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

  if connection.input_buffer.len - start != u32(size) {
    fmt.println("size read and size announced does not match")
    return false
  }


  values := connection.values.data[0:connection.values.len]
  //fmt.println("event", object_id, opcode, size, values)

  object.callbacks[opcode](connection, values)

  return true
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
  if connection.output_buffer.len == 0 {
    return
  }

  fmt.println("sending:", connection.output_buffer.data[0:connection.output_buffer.len])

  count := posix.send(connection.socket, raw_data(connection.output_buffer.data), uint(connection.output_buffer.len), { })

  if u32(count) != connection.output_buffer.len {
    fmt.println("Failed to send every information into the socket, total:", count)
  }

  connection.output_buffer.len = 0
}

connection_append :: proc(connection: ^Connection, callbacks: []CallbackConfig, interface: ^wl.Interface, allocator := context.allocator) {
  if len(callbacks) != len(interface.events) {
    fmt.println("registering the wrong number of callbacks into", interface.name)
  }

  object: Object
  object.interface = interface
  object.callbacks = make([]Callback, len(callbacks), allocator)

  for callback in callbacks {
    opcode := get_event_opcode(interface, callback.name)
    object.callbacks[opcode] = callback.function
  }

  vec_append(&connection.objects, object)
}

get_object :: proc(connection: ^Connection, id: u32) -> Object {
  return connection.objects.data[id - 1]
}

get_id :: proc(connection: ^Connection, name: string, callbacks: []CallbackConfig, interfaces: []wl.Interface, allocator := context.allocator) -> u32 {
  for &inter in interfaces {
    if inter.name == name {
      defer connection_append(connection, callbacks, &inter, allocator)
      return connection.objects.len + 1
    }
  }

  fmt.println(name)
  panic("interface id  not found")
}

get_event :: proc(object: Object, opcode: u32) -> ^wl.Event {
  return &object.interface.events[opcode]
}

get_request :: proc(object: Object, opcode: u32) -> ^wl.Request {
  return &object.interface.requests[opcode]
}

get_event_opcode :: proc(interface: ^wl.Interface, name: string) -> u32 {
  for event, i in interface.events {
    if event.name == name {
      return u32(i)
    }
  }

  fmt.println(name)
  panic("event  opcode not found")
}

get_request_opcode :: proc(connection: ^Connection, name: string, object_id: u32) -> u32 {
  requests := get_object(connection, object_id).interface.requests

  for request, i in requests {
    if request.name == name {
      return u32(i)
    }
  }
  
  fmt.println(name)
  panic("request opcode not found")
}

error_callback :: proc(connection: ^Connection, arguments: []wl.Argument) {
    fmt.println("error: code", arguments[1], string(arguments[2].(wl.String)))
}

format_callback :: proc(connection: ^Connection, arguments: []wl.Argument) {
  fmt.println("formats", arguments)
}

global_callback :: proc(connection: ^Connection, arguments: []wl.Argument) {
  str := arguments[1].(wl.String)
  switch string(str[0:len(str) - 1]) {
  case "wl_shm":
    connection.shm_id = get_id( connection, "wl_shm", { callback_config("format", format_callback) } , wl.WAYLAND_INTERFACES[:], context.allocator)
    write(connection, { arguments[0], wl.UnBoundNewId{ id = wl.BoundNewId(connection.shm_id), interface = arguments[1].(wl.String), version = arguments[2].(wl.Uint) }}, connection.registry_id, connection.registry_bind_opcode)
  case "wl_compositor":
    connection.compositor_id = get_id( connection, "wl_compositor", { } , wl.WAYLAND_INTERFACES[:], context.allocator)
    write(connection, { arguments[0], wl.UnBoundNewId{ id = wl.BoundNewId(connection.compositor_id), interface = arguments[1].(wl.String), version = arguments[2].(wl.Uint) }}, connection.registry_id, connection.registry_bind_opcode)
  }
    fmt.println("registry global on: name", arguments[0].(wl.Uint), "interface:", string(arguments[1].(wl.String)), "version:", connection.values.data[2].(wl.Uint))
}

null_callback :: proc(connection: ^Connection, arguments: []wl.Argument) {
  fmt.println("null callback")
}

callback_config :: proc(name: string, callback: Callback) -> CallbackConfig {
  return CallbackConfig {
    name = name,
    function = callback,
  }
}
