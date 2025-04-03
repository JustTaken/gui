package main

import "core:mem"

main :: proc() {
  bytes: []u8
  ctx: VulkanContext
  arena: mem.Arena
  tmp_arena: mem.Arena

  if bytes = make([]u8, 1024 * 1024 * 100); bytes == nil do panic("Out of memory")
  defer delete(bytes)

  mem.arena_init(&arena, bytes)
  context.allocator = mem.arena_allocator(&arena)

  mem.arena_init(&tmp_arena, make([]u8, 1024 * 1024 * 50, context.allocator))
  context.temp_allocator = mem.arena_allocator(&tmp_arena)

  if !init_vulkan(&ctx, &arena, &tmp_arena) do panic("Failed to initialize vulkan")
  defer deinit_vulkan(&ctx)

  if !init_wayland(&arena, &tmp_arena) do panic("Failed to initialize wayland")

  if !draw(&ctx) do panic("Failed to draw frame")
  if !write_image(&ctx) do panic("Failed to write image")
}
