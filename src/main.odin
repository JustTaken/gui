package main

import "core:fmt"
import "core:mem"

main :: proc() {
  bytes: []u8
  wl: WaylandContext
  vk: VulkanContext
  arena: mem.Arena
  tmp_arena: mem.Arena

  width: u32 = 1920
  height: u32 = 1080
  frames: u32 = 2

  if bytes = make([]u8, 1024 * 1024 * 20); bytes == nil do panic("Out of memory")
  defer delete(bytes)

  mem.arena_init(&arena, bytes)
  context.allocator = mem.arena_allocator(&arena)

  mem.arena_init(&tmp_arena, make([]u8, 1024 * 1024 * 5, context.allocator))
  context.temp_allocator = mem.arena_allocator(&tmp_arena)

  {
    mark := mem.begin_arena_temp_memory(&tmp_arena)
    defer mem.end_arena_temp_memory(mark)
    if !init_vulkan(&vk, 1920, 1080, frames, &arena, &tmp_arena) do panic("Failed to initialize vulkan")
  }

  defer deinit_vulkan(&vk)

  {
    mark := mem.begin_arena_temp_memory(&tmp_arena)
    defer mem.end_arena_temp_memory(mark)
    if !init_wayland(&wl, &vk, width, height, frames, &arena, &tmp_arena) do panic("Failed to initialize wayland")
  }

  defer deinit_wayland(&wl)

  for wl.running { 
    mark := mem.begin_arena_temp_memory(&tmp_arena)
    defer mem.end_arena_temp_memory(mark)

    if !render(&wl) {
      fmt.println("Failed to render frame")
    }
  }

  fmt.println("TMP", tmp_arena.offset, tmp_arena.peak_used)
  fmt.println("MAIN", arena.offset - len(tmp_arena.data), arena.peak_used - len(tmp_arena.data))
}
