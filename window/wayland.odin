package main

import "core:os" 
import "core:sys/posix"
import "core:fmt"
import "core:path/filepath" 
import "core:mem"
import "wayland"

main :: proc() {
  arena: mem.Arena
  bytes := make([]u8, 1024 * 1024 * 1)
  mem.arena_init(&arena, bytes)
  context.allocator = mem.arena_allocator(&arena)

  socket, ok := connect(context.allocator)

  if !ok {
    fmt.println("Failed to open wayland connection")
    return
  }

  fmt.println("Success on connecting to stblish wayland connection")
}

connect :: proc(allocator := context.allocator) -> (posix.FD, bool) {
  xdg_path := os.get_env("XDG_RUNTIME_DIR", allocator = allocator)
  wayland_path := os.get_env("WAYLAND_DISPLAY", allocator = allocator)
  socket: posix.FD

  if len(xdg_path) == 0 || len(wayland_path) == 0 {
    fmt.println("Failed to get env variables")
    return socket, false
  }

  path := filepath.join({ xdg_path, wayland_path }, allocator)
  socket = posix.socket(.UNIX, .STREAM)

  if socket < 0 {
    fmt.println("Failed to create unix socket")
    return socket, false
  }

  sockaddr := posix.sockaddr_un {
    sun_family = .UNIX,
  }

  count: uint = 0
  for c in path {
    sockaddr.sun_path[count] = u8(c)
    count += 1
  }

  result := posix.connect(socket, (^posix.sockaddr)(&sockaddr), posix.socklen_t(size_of(posix.sockaddr_un)))

  if result == .FAIL {
    fmt.println("Failed to connect to compositor socket")
    return socket, false
  }

  return socket, true
}
