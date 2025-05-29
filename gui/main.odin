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
import "lib:xkb"

View :: struct {
  rotation: [3]f32,
  translation: [3]f32,
  arrow: [3]f32,
}

Context :: struct {
  bytes: []u8,

  wl: wayland.Wayland_Context,
  vk: vulkan.Vulkan_Context,
  view: View,
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

  view_update: bool,

  scenes: Scenes,

  ambient: Scene_Instance,
  player: Scene_Instance,

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

    //tick_scene_animation(&ctx, &ctx.scene, time.now()._nsec) or_return

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

  //ctx.view = linalg.matrix4_translate_f32({0, -5, -20})

  ctx.view.arrow = {-2.5, 2, -10} 
  ctx.scenes = load_gltf_scenes(ctx, "assets/scene.gltf", 1) or_return
  ctx.ambient = scene_instance_create(ctx, &ctx.scenes, "Ambient", linalg.matrix4_translate_f32({0, -5, -20}), .WithView) or_return
  ctx.player = scene_instance_create(ctx, &ctx.scenes, "Arrows", linalg.matrix4_translate_f32(ctx.view.arrow), .WithoutView) or_return

  wayland.add_listener(&ctx.wl, ctx, frame) or_return
  vulkan.update_view(&ctx.vk, linalg.MATRIX4F32_IDENTITY) or_return
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

view_translate :: proc(ctx: ^Context, translation: [3]f32) {
  ctx.view.translation += translation
  ctx.view_update = true
}

view_rotate :: proc(ctx: ^Context, rotation: [3]f32) {
  ctx.view.rotation += rotation
  ctx.view_update = true
}

frame :: proc(ptr: rawptr, keymap: ^xkb.Keymap_Context, time: i64) -> error.Error {
  ctx := cast(^Context)(ptr)
  ctx.view_update = false

  angle_velocity: f32 = 3.14 / 64.0
  translation_velocity: f32 = 2.0 / 4.0

  if xkb.is_key_pressed(keymap, .d) do view_translate(ctx, {-translation_velocity, 0, 0})
  if xkb.is_key_pressed(keymap, .a) do view_translate(ctx, {translation_velocity, 0, 0})
  if xkb.is_key_pressed(keymap, .s) do view_translate(ctx, {0, 0, -translation_velocity})
  if xkb.is_key_pressed(keymap, .w) do view_translate(ctx, {0, 0, translation_velocity})
  if xkb.is_key_pressed(keymap, .k) do view_translate(ctx, {0, -translation_velocity, 0})
  if xkb.is_key_pressed(keymap, .j) do view_translate(ctx, {0, translation_velocity, 0})
  if xkb.is_key_pressed(keymap, .ArrowUp) do view_rotate(ctx, {0, 1, 0})
  if xkb.is_key_pressed(keymap, .ArrowDown) do view_rotate(ctx, {0, -1, 0})
  if xkb.is_key_pressed(keymap, .ArrowLeft) do view_rotate(ctx, {1, 0, 0})
  if xkb.is_key_pressed(keymap, .ArrowRight) do view_rotate(ctx, {-1, 0, 0})

  if ctx.view_update {
    up := linalg.matrix4_rotate(angle_velocity * ctx.view.rotation[1], [3]f32{1, 0, 0})
    left := linalg.matrix4_rotate(angle_velocity * ctx.view.rotation[0], [3]f32{0, 1, 0})

    view := up * left  

    vulkan.update_view(ctx.wl.vk, view * linalg.matrix4_translate_f32(ctx.view.translation)) or_return
    scene_instance_update(ctx, &ctx.player, linalg.matrix4_translate_f32(ctx.view.arrow) * view) or_return
  }

  return nil
}
