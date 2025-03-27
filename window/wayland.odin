package main

import "core:fmt"
import "core:mem"
import wl "wayland"

main :: proc() {
  arena: mem.Arena
  bytes := make([]u8, 1024 * 1024 * 1)
  mem.arena_init(&arena, bytes)
  context.allocator = mem.arena_allocator(&arena)

  connection, ok := wl.connect(context.allocator)

  if !ok {
    fmt.println("Failed to open wayland connection")
    return
  }

  connection.display_id = wl.get_id(&connection, "wl_display", { wl.callback_config("error", error_callback), wl.callback_config("delete_id", null_callback) }, wl.WAYLAND_INTERFACES[:], context.allocator)
  connection.registry_id = wl.get_id(&connection, "wl_registry", { wl.callback_config("global", global_callback), wl.callback_config("global_remove", null_callback) }, wl.WAYLAND_INTERFACES[:], context.allocator)
  connection.get_registry_opcode = wl.get_request_opcode(&connection, "get_registry", connection.display_id)

  wl.write(&connection, { wl.BoundNewId(connection.registry_id) }, connection.display_id, connection.get_registry_opcode)
  wl.send(&connection)

  for {
    success := wl.read(&connection);

    if !success {
      wl.send(&connection)
      wl.recv(&connection)
    }
  }
}

error_callback :: proc(connection: ^wl.Connection, arguments: []wl.Argument) {
    fmt.println("error: code", arguments[1], string(arguments[2].(wl.String)))
}

format_callback :: proc(connection: ^wl.Connection, arguments: []wl.Argument) {
  format := u32(arguments[0].(wl.Uint))

  if format == 0 {
    wl.create_shm_pool(connection, format, 150 * 150 * 4)
  }
}

global_callback :: proc(connection: ^wl.Connection, arguments: []wl.Argument) {
  str := arguments[1].(wl.String)
  switch string(str[0:len(str) - 1]) {
  case "wl_shm":
    connection.shm_id = wl.get_id( connection, "wl_shm", { wl.callback_config("format", format_callback) } , wl.WAYLAND_INTERFACES[:], context.allocator)
    wl.write(connection, { arguments[0], wl.UnBoundNewId{ id = wl.BoundNewId(connection.shm_id), interface = arguments[1].(wl.String), version = arguments[2].(wl.Uint) }}, connection.registry_id, connection.registry_bind_opcode)
  case "wl_compositor":
    connection.compositor_id = wl.get_id( connection, "wl_compositor", { } , wl.WAYLAND_INTERFACES[:], context.allocator)
    wl.write(connection, { arguments[0], wl.UnBoundNewId{ id = wl.BoundNewId(connection.compositor_id), interface = arguments[1].(wl.String), version = arguments[2].(wl.Uint) }}, connection.registry_id, connection.registry_bind_opcode)
  }
    fmt.println("registry global on: name", arguments[0].(wl.Uint), "interface:", string(arguments[1].(wl.String)), "version:", connection.values.data[2].(wl.Uint))
}

null_callback :: proc(connection: ^wl.Connection, arguments: []wl.Argument) {
  fmt.println("null callback")
}

