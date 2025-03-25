package main

import "core:os" 
import "core:sys/posix"
import "core:fmt"
import "core:path/filepath" 
import "base:intrinsics"
import "core:mem"
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

  fmt.println("Success on connecting")

  display_id := get_id(&connection, "wl_display", wl.WAYLAND_INTERFACES[:])
  registry_id := get_id(&connection, "wl_registry", wl.WAYLAND_INTERFACES[:])
  get_registry_opcode := get_request_opcode(&connection, "get_registry", display_id)

  write(&connection, { wl.BoundNewId(registry_id) }, display_id, get_registry_opcode)
  send(&connection)
}

Connection :: struct {
  socket: posix.FD,
  objects: []^wl.Interface,
  object_len: u32,
  object_capacity: u32,
  buffer: []u8,
  buffer_len: u32,
  buffer_capacity: u32,
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

  connection.object_len = 0
  connection.object_capacity = 40

  if connection.objects, err = make([]^wl.Interface, connection.object_capacity); err != nil {
    return connection, false
  }

  connection.buffer_len = 0
  connection.buffer_capacity = 4096

  if connection.buffer, err = make([]u8, connection.buffer_capacity); err != nil {
    return connection, false
  }

  return connection, true
}

write :: proc(connection: ^Connection, arguments: []wl.Argument, object_id: u32, opcode: u32) {
  object := connection.objects[object_id]
  request := &object.requests[opcode]

  start: = connection.buffer_len
  total_len: u32= size_of(u32) + size_of(u16) + size_of(u16)

  for kind, i in request.arguments {
    #partial switch kind {
    case .BoundNewId:
      intrinsics.unaligned_store((^wl.BoundNewId)(raw_data(connection.buffer[start + total_len:])), arguments[i].(wl.BoundNewId))
      total_len += size_of(wl.BoundNewId)
    case:
    }
  }

  intrinsics.unaligned_store((^u32)(raw_data(connection.buffer[:])), object_id)
  intrinsics.unaligned_store((^u16)(raw_data(connection.buffer[1 * size_of(u32):])), u16(opcode))
  intrinsics.unaligned_store((^u16)(raw_data(connection.buffer[2 * size_of(u32):])), u16(total_len))

  connection.buffer_len += total_len
}

send :: proc(connection: ^Connection) {
  defer connection.buffer_len = 0
  count := posix.send(connection.socket, rawptr(&connection.buffer[0]), uint(connection.buffer_len), { })

  if u32(count) != connection.buffer_len {
    fmt.println("Failed to send every information into the socket, total:", count)
  } else {
    fmt.println("just send:", count, "bytes into the network")
  }
}

connection_append :: proc(connection: ^Connection, interface: ^wl.Interface) {
  connection.objects[connection.object_len] = interface
  connection.object_len += 1
}

get_id :: proc(connection: ^Connection, name: string, interfaces: []wl.Interface) -> u32 {
  for &inter in interfaces {
    if inter.name == name {
      defer connection_append(connection, &inter)
      return connection.object_len
    }
  }

  return 0
}

get_request_opcode :: proc(connection: ^Connection, name: string, object_id: u32) -> u32 {
  for request, i in connection.objects[object_id].requests {
    if request.name == name {
      return u32(i)
    }
  }

  return 0
}

