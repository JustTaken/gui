package main

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:math/linalg"
import "core:log"
import "core:time"

import "lib:collection/vector"
import "lib:collection/gltf"
import "lib:vulkan"
import "lib:wayland"
import "lib:error"

Context :: struct {
  bytes: []u8,

  wl: wayland.Wayland_Context,
  vk: vulkan.Vulkan_Context,
  view: matrix[4, 4]f32,
  rotate_up: matrix[4, 4]f32,
  rotate_down: matrix[4, 4]f32,
  rotate_left: matrix[4, 4]f32,
  rotate_right: matrix[4, 4]f32,
  translate_right: matrix[4, 4]f32,
  translate_left: matrix[4, 4]f32,
  translate_down: matrix[4, 4]f32,
  translate_up: matrix[4, 4]f32,
  translate_back: matrix[4, 4]f32,
  translate_for: matrix[4, 4]f32,
  scenes: vector.Vector(Scene),


  view_update: bool,

  cube: ^Scene,
  bone: ^Scene,

  cube_instance: Scene_Instance,

  allocator: runtime.Allocator,
  arena: mem.Arena,

  tmp_allocator: runtime.Allocator,
  tmp_arena: mem.Arena,
}

log_proc :: proc(data: rawptr, level: runtime.Logger_Level, text: string, options: runtime.Logger_Options, location := #caller_location) {
  fmt.println("[", level, "] ->", text)
}

main :: proc() {
  context.logger.lowest_level = .Info
  context.logger.procedure = log_proc

  if err := run(1920, 1080, 2); err != nil {
    log.error("Failed to run application", err)
  }
}

run :: proc(width: u32, height: u32, frames: u32) -> error.Error {
  ctx: Context

  init_memory(&ctx, 1024 * 1024 * 2, 2) or_return
  init_scene(&ctx, width, height, frames) or_return

  for ctx.wl.running {
    mark := mem.begin_arena_temp_memory(&ctx.tmp_arena)
    defer mem.end_arena_temp_memory(mark)

    tick_scene_animation(&ctx, &ctx.cube_instance, time.now()._nsec) or_return

    if wayland.render(&ctx.wl) != nil {
      log.error("Failed to render frame")
    }
  }

  deinit(&ctx)

  return nil
}

init_memory :: proc(ctx: ^Context, bytes: u32, divisor: u32) -> error.Error {
  if bytes, m_err := make([]u8, bytes, context.allocator); m_err == nil {
    ctx.bytes = bytes
  } else {
    log.error("Primary allocation failed:")
    return .OutOfMemory
  }

  mem.arena_init(&ctx.arena, ctx.bytes)
  ctx.allocator = mem.arena_allocator(&ctx.arena)

  mem.arena_init(&ctx.tmp_arena, make([]u8, bytes / divisor, ctx.allocator))
  ctx.tmp_allocator = mem.arena_allocator(&ctx.tmp_arena)

  return nil;
}

init_scene :: proc(ctx: ^Context, width: u32, height: u32, frames: u32) ->  error.Error {
  vulkan.vulkan_init(&ctx.vk, width, height, frames, &ctx.arena, &ctx.tmp_arena) or_return
  wayland.wayland_init(&ctx.wl, &ctx.vk, width, height, frames, &ctx.arena, &ctx.tmp_arena) or_return

  angle_velocity: f32 = 3.14 / 64.0
  translation_velocity: f32 = 2.0 / 4.0

  ctx.rotate_up = linalg.matrix4_rotate_f32(angle_velocity, [3]f32{1, 0, 0})
  ctx.rotate_down = linalg.matrix4_rotate_f32(angle_velocity, [3]f32{-1, 0, 0})
  ctx.rotate_left = linalg.matrix4_rotate_f32(angle_velocity, [3]f32{0, -1, 0})
  ctx.rotate_right = linalg.matrix4_rotate_f32(angle_velocity, [3]f32{0, 1, 0})
  ctx.translate_right = linalg.matrix4_translate_f32({translation_velocity, 0, 0})
  ctx.translate_left = linalg.matrix4_translate_f32({-translation_velocity, 0, 0})
  ctx.translate_down = linalg.matrix4_translate_f32({0, translation_velocity, 0})
  ctx.translate_up = linalg.matrix4_translate_f32({0, -translation_velocity, 0})
  ctx.translate_back = linalg.matrix4_translate_f32({0, 0, -translation_velocity})
  ctx.translate_for = linalg.matrix4_translate_f32({0, 0, translation_velocity})

  ctx.view = linalg.matrix4_translate_f32({0, 0, -10})
  ctx.scenes = vector.new(Scene, 20, ctx.allocator) or_return

  ctx.cube = load_gltf_scene(ctx, "assets/rotation.gltf", 1) or_return
  ctx.cube_instance = scene_instance_create(ctx, ctx.cube, linalg.MATRIX4F32_IDENTITY) or_return

  wayland.add_listener(&ctx.wl, ctx, frame) or_return
  vulkan.update_view(&ctx.vk, ctx.view) or_return
  vulkan.update_light(&ctx.vk, {0, 0, 0}) or_return

  return nil
}

deinit :: proc(ctx: ^Context) {
  wayland.wayland_deinit(&ctx.wl)
  vulkan.vulkan_deinit(&ctx.vk)

  log.info("TMP", ctx.tmp_arena.offset, ctx.tmp_arena.peak_used)
  log.info("MAIN", ctx.arena.offset - len(ctx.tmp_arena.data), ctx.arena.peak_used - len(ctx.tmp_arena.data))

  delete(ctx.bytes)
}

new_view :: proc(ctx: ^Context, view: matrix[4, 4]f32) {
  ctx.view = view
  ctx.view_update = true
}

frame :: proc(ptr: rawptr, keymap: ^wayland.Keymap_Context, time: i64) -> error.Error {
  ctx := cast(^Context)(ptr)
  ctx.view_update = false

  if wayland.is_key_pressed(keymap, .d) do new_view(ctx, ctx.translate_left * ctx.view)
  if wayland.is_key_pressed(keymap, .a) do new_view(ctx, ctx.translate_right * ctx.view)
  if wayland.is_key_pressed(keymap, .s) do new_view(ctx, ctx.translate_back * ctx.view)
  if wayland.is_key_pressed(keymap, .w) do new_view(ctx, ctx.translate_for * ctx.view)
  if wayland.is_key_pressed(keymap, .k) do new_view(ctx, ctx.translate_up * ctx.view)
  if wayland.is_key_pressed(keymap, .j) do new_view(ctx, ctx.translate_down * ctx.view)
  if wayland.is_key_pressed(keymap, .ArrowUp) do new_view(ctx, ctx.rotate_up * ctx.view)
  if wayland.is_key_pressed(keymap, .ArrowDown) do new_view(ctx, ctx.rotate_down * ctx.view)
  if wayland.is_key_pressed(keymap, .ArrowLeft) do new_view(ctx, ctx.rotate_left * ctx.view)
  if wayland.is_key_pressed(keymap, .ArrowRight) do new_view(ctx, ctx.rotate_right * ctx.view)

  if wayland.is_key_pressed(keymap, .Space) {
    play_scene_animation(&ctx.cube_instance, "FAnime", time) or_return
  }

  if ctx.view_update do vulkan.update_view(ctx.wl.vk, ctx.view) or_return

  return nil
}
