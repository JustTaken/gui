package main

import "core:mem"
import wl "wayland"

main :: proc() {
  arena: mem.Arena
  bytes := make([]u8, 1024 * 1024 * 1)
  mem.arena_init(&arena, bytes)
  context.allocator = mem.arena_allocator(&arena)

  if !handle() {
    return
  }
}

handle :: proc() -> bool {
  connection := wl.connect(600, 400, context.allocator) or_return

  connection.display_id = wl.get_id(&connection, "wl_display", { wl.new_callback("error", error_callback), wl.new_callback("delete_id", delete_callback) }, wl.WAYLAND_INTERFACES[:], context.allocator)
  connection.registry_id = wl.get_id(&connection, "wl_registry", { wl.new_callback("global", global_callback), wl.new_callback("global_remove", global_remove_callback) }, wl.WAYLAND_INTERFACES[:], context.allocator)
  connection.get_registry_opcode = wl.get_request_opcode(&connection, "get_registry", connection.display_id)

  wl.write(&connection, { wl.BoundNewId(connection.registry_id) }, connection.display_id, connection.get_registry_opcode)
  wl.send(&connection) or_return

  read(&connection)
  read(&connection)

  for connection.running && read(&connection) {}

  return true
}

read :: proc(connection: ^wl.Connection) -> bool {
  wl.recv(connection)

  for wl.read(connection) { }
  return wl.send(connection)
}

commit :: proc(connection: ^wl.Connection) {
  wl.write(connection, { }, connection.surface_id, connection.surface_commit_opcode)
}

create_surface :: proc(connection: ^wl.Connection) {
  connection.surface_id = wl.get_id(connection, "wl_surface", { wl.new_callback("enter", enter_callback), wl.new_callback("leave", leave_callback), wl.new_callback("preferred_buffer_scale", preferred_buffer_scale_callback), wl.new_callback("preferred_buffer_transform", preferred_buffer_transform_callback) }, wl.WAYLAND_INTERFACES[:], context.allocator)
  connection.surface_attach_opcode = wl.get_request_opcode(connection, "attach", connection.surface_id)
  connection.surface_commit_opcode = wl.get_request_opcode(connection, "commit", connection.surface_id)

  wl.write(connection, { wl.BoundNewId(connection.surface_id) }, connection.compositor_id, connection.create_surface_opcode)
}

create_xdg_surface :: proc(connection: ^wl.Connection) {
  connection.xdg_surface_id = wl.get_id(connection, "xdg_surface", { wl.new_callback("configure", configure_callback) }, wl.XDG_INTERFACES[:], context.allocator)
  connection.get_toplevel_opcode = wl.get_request_opcode(connection, "get_toplevel", connection.xdg_surface_id)
  connection.ack_configure_opcode = wl.get_request_opcode(connection, "ack_configure", connection.xdg_surface_id)
  connection.xdg_toplevel_id = wl.get_id(connection, "xdg_toplevel", { wl.new_callback("configure", toplevel_configure_callback), wl.new_callback("close", toplevel_close_callback), wl.new_callback("configure_bounds", toplevel_configure_bounds_callback), wl.new_callback("wm_capabilities", toplevel_wm_capabilities_callback) }, wl.XDG_INTERFACES[:], context.allocator)

  wl.write(connection, { wl.BoundNewId(connection.xdg_surface_id), wl.Object(connection.surface_id) }, connection.xdg_wm_base_id, connection.get_xdg_surface_opcode)
  wl.write(connection, { wl.BoundNewId(connection.xdg_toplevel_id) }, connection.xdg_surface_id, connection.get_toplevel_opcode)

  create_shm_pool(connection, 1920, 1080)

  commit(connection)
}

create_shm_pool :: proc(connection: ^wl.Connection, max_width: u32, max_height: u32) {
  color_channels: u32 = 4

  connection.shm_pool_id = wl.get_id(connection, "wl_shm_pool", {}, wl.WAYLAND_INTERFACES[:], context.allocator)
  connection.create_buffer_opcode = wl.get_request_opcode(connection, "create_buffer", connection.shm_pool_id)

  connection.buffer_id = wl.get_id(connection, "wl_buffer", { wl.new_callback("release", buffer_release_callback) }, wl.WAYLAND_INTERFACES[:], context.allocator)
  connection.destroy_buffer_opcode = wl.get_request_opcode(connection, "destroy", connection.buffer_id)

  wl.create_shm_pool(connection, max_width * max_height * color_channels)
  wl.write(connection, { wl.BoundNewId(connection.buffer_id), wl.Int(0), wl.Int(connection.width), wl.Int(connection.height), wl.Int(color_channels * connection.width), wl.Uint(connection.format) }, connection.shm_pool_id, connection.create_buffer_opcode)

  l := connection.width * connection.height * color_channels
  connection.buffer = connection.shm_pool[0:l]
  for i in 0..<l {
    connection.buffer[i] = 255
  }
}

format_callback :: proc(connection: ^wl.Connection, id: u32, arguments: []wl.Argument) {
  format := u32(arguments[0].(wl.Uint))

  if format != 0 do return

  connection.format = format
}

global_callback :: proc(connection: ^wl.Connection, id: u32, arguments: []wl.Argument) {
  str := arguments[1].(wl.String)
  version := arguments[2].(wl.Uint)
  interface_name := string(str[0:len(str) - 1])

  switch interface_name {
  case "wl_shm":
    connection.shm_id = wl.get_id(connection, interface_name, { wl.new_callback("format", format_callback) } , wl.WAYLAND_INTERFACES[:], context.allocator)
    connection.create_shm_pool_opcode = wl.get_request_opcode(connection, "create_pool", connection.shm_id);

    wl.write(connection, { arguments[0], wl.UnBoundNewId{ id = wl.BoundNewId(connection.shm_id), interface = str, version = version }}, connection.registry_id, connection.registry_bind_opcode)
  case "xdg_wm_base":
    connection.xdg_wm_base_id = wl.get_id(connection, interface_name, { wl.new_callback("ping", ping_callback) }, wl.XDG_INTERFACES[:], context.allocator)
    connection.pong_opcode = wl.get_request_opcode(connection, "pong", connection.xdg_wm_base_id)
    connection.get_xdg_surface_opcode = wl.get_request_opcode(connection, "get_xdg_surface", connection.xdg_wm_base_id)

    wl.write(connection, { arguments[0], wl.UnBoundNewId{ id = wl.BoundNewId(connection.xdg_wm_base_id), interface = str, version = version }}, connection.registry_id, connection.registry_bind_opcode)
    create_xdg_surface(connection)
  case "wl_compositor":
    connection.compositor_id = wl.get_id( connection, interface_name, { } , wl.WAYLAND_INTERFACES[:], context.allocator)
    connection.create_surface_opcode = wl.get_request_opcode(connection, "create_surface", connection.compositor_id)

    wl.write(connection, { arguments[0], wl.UnBoundNewId{ id = wl.BoundNewId(connection.compositor_id), interface = str, version = version }}, connection.registry_id, connection.registry_bind_opcode)
    create_surface(connection)
  }
}

global_remove_callback :: proc(connection: ^wl.Connection, id: u32, arguments: []wl.Argument) {
}

configure_callback :: proc(connection: ^wl.Connection, id: u32, arguments: []wl.Argument) {
  wl.write(connection, { arguments[0] }, id, connection.ack_configure_opcode)
  wl.write(connection, { wl.Object(connection.buffer_id), wl.Int(0), wl.Int(0) }, connection.surface_id, connection.surface_attach_opcode)
  commit(connection)
}

ping_callback :: proc(connection: ^wl.Connection, id: u32, arguments: []wl.Argument) {
  wl.write(connection, { arguments[0] }, connection.xdg_wm_base_id, connection.pong_opcode)
}

toplevel_configure_callback :: proc(connection: ^wl.Connection, id: u32, arguments: []wl.Argument) {
  width := u32(arguments[0].(wl.Int))
  height := u32(arguments[1].(wl.Int))

  if width == 0 || height == 0 do return
  if width == connection.width && height == connection.height do return

  connection.width = width
  connection.height = height
  connection.resize = true
}

toplevel_close_callback :: proc(connection: ^wl.Connection, id: u32, arugments: []wl.Argument) {
  connection.running = false
}

toplevel_configure_bounds_callback :: proc(connection: ^wl.Connection, id: u32, arugments: []wl.Argument) {
}

toplevel_wm_capabilities_callback :: proc(connection: ^wl.Connection, id: u32, arugments: []wl.Argument) {
}

buffer_release_callback :: proc(connection: ^wl.Connection, id: u32, arguments: []wl.Argument) {
  if connection.resize {
    wl.write(connection, {}, id, connection.destroy_buffer_opcode)
    wl.write(connection, { wl.BoundNewId(id), wl.Int(0), wl.Int(connection.width), wl.Int(connection.height), wl.Int(4 * connection.width), wl.Uint(connection.format) }, connection.shm_pool_id, connection.create_buffer_opcode)
 
    l := connection.width * connection.height * 4
    connection.buffer = connection.shm_pool[0:l]
    for i in 0..<l {
      connection.buffer[i] = 255
    }
   
    connection.resize = false
    wl.write(connection, { wl.Object(connection.buffer_id), wl.Int(0), wl.Int(0) }, connection.surface_id, connection.surface_attach_opcode)
    commit(connection)
  }
}

enter_callback :: proc(connection: ^wl.Connection, id: u32, arguments: []wl.Argument) {
}

leave_callback :: proc(connection: ^wl.Connection, id: u32, arguments: []wl.Argument) {
}

preferred_buffer_scale_callback :: proc(connection: ^wl.Connection, id: u32, arguments: []wl.Argument) {
}

preferred_buffer_transform_callback :: proc(connection: ^wl.Connection, id: u32, arguments: []wl.Argument) {
}

delete_callback :: proc(connection: ^wl.Connection, id: u32, arguments: []wl.Argument) {
}

error_callback :: proc(connection: ^wl.Connection, id: u32, arguments: []wl.Argument) {
}

