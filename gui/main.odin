package main

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:math/linalg"
import "core:log"
import "core:time"

import "collection"
import gltf "collection/gltf"
import vk "vulkan"
import wl "wayland"
import "error"

Context :: struct {
  // gltfs: collection.Vector(Gltf),
  wl: ^wl.Wayland_Context,
  view: matrix[4, 4]f32,
  rotate_up: matrix[4, 4]f32,
  rotate_down: matrix[4, 4]f32,
  rotate_left: matrix[4, 4]f32,
  rotate_right: matrix[4, 4]f32,
  translate_right: matrix[4, 4]f32,
  translate_left: matrix[4, 4]f32,
  translate_back: matrix[4, 4]f32,
  translate_for: matrix[4, 4]f32,
  // current_animations: collection.Vector(Animation)
}

log_proc :: proc(data: rawptr, level: runtime.Logger_Level, text: string, options: runtime.Logger_Options, location := #caller_location) {
  fmt.println("[", level, "] ->", text)
}

main :: proc() {
  bytes: []u8
  err: mem.Allocator_Error
  arena: mem.Arena
  tmp_arena: mem.Arena

  w: wl.Wayland_Context
  v: vk.Vulkan_Context

  width: u32 = 1920
  height: u32 = 1080
  frames: u32 = 2

  context.logger.lowest_level = .Info
  context.logger.procedure = log_proc

 if bytes, err = make([]u8, 1024 * 1024 * 2, context.allocator); err != nil {
    log.error("Primary allocation failed:", err)
    return
  }

  defer delete(bytes)

  mem.arena_init(&arena, bytes)
  context.allocator = mem.arena_allocator(&arena)

  mem.arena_init(&tmp_arena, make([]u8, 1024 * 1024 * 1, context.allocator))
  context.temp_allocator = mem.arena_allocator(&tmp_arena)

  if e := init(&v, &w, width, height, frames, &arena, &tmp_arena); e != nil {
    log.error("Failed to initialize environment:", e)
    return
  }

  if e := loop(&v, &w); e != nil {
    log.error("Could not complete loop due to error:", e)
    return
  }

  wl.wayland_deinit(&w)
  vk.vulkan_deinit(&v)

  log.info("TMP", tmp_arena.offset, tmp_arena.peak_used)
  log.info("MAIN", arena.offset - len(tmp_arena.data), arena.peak_used - len(tmp_arena.data))
}

init :: proc(v: ^vk.Vulkan_Context, w: ^wl.Wayland_Context, width: u32, height: u32, frames: u32, arena: ^mem.Arena, tmp_arena: ^mem.Arena) -> error.Error {
    vk.vulkan_init(v, width, height, frames, arena, tmp_arena) or_return
    wl.wayland_init(w, v, width, height, frames, arena, tmp_arena) or_return

    return nil
}

load_node :: proc(v: ^vk.Vulkan_Context, node: ^gltf.Node) -> error.Error {
  if node.mesh == nil do return  nil

  Vertex :: struct {
    position: [3]f32,
    normal: [3]f32,
    texture: [2]f32,
  }

  for primitive in node.mesh.primitives {
    positions := primitive.accessors[.Position]
    normals := primitive.accessors[.Normal]
    textures := primitive.accessors[.Texture0]

    assert(positions.component_kind == .F32 && positions.component_count == 3)
    assert(normals.component_kind == .F32 && normals.component_count == 3)
    assert(textures.component_kind == .F32 && textures.component_count == 2)
    assert(size_of(Vertex) == (size_of(f32) * positions.component_count) + (size_of(f32) * normals.component_count) + (size_of(f32) * textures.component_count))

    count := positions.count
    size := size_of(Vertex) * count

    indices := primitive.indices
    bytes := make([]u8, size, v.tmp_allocator)

    pos := cast([^][3]f32)raw_data(positions.bytes)
    norms := cast([^][3]f32)raw_data(normals.bytes)
    texts := cast([^][2]f32)raw_data(textures.bytes)
    vertices := cast([^]Vertex)raw_data(bytes)

    for i in 0..<count {
      vertices[i].position = pos[i]
      vertices[i].normal = norms[i]
      vertices[i].texture = texts[i]
    }

    transform := node.transform

    geometry := vk.geometry_create(v, bytes, size_of(Vertex), count, indices.bytes, gltf.get_accessor_size(indices), indices.count, 1) or_return
    instance := vk.geometry_instance_add(v, geometry, transform, {0, 1, 1, 1}) or_return
  }

  return nil
}
load_gltf :: proc(v: ^vk.Vulkan_Context, path: string) -> error.Error {
  fmt.println("Loading gltf file", path)

  glt := gltf.from_file(path, v.allocator) or_return
  scene := &glt.scenes["Scene"]

  for j in 0..<len(scene.nodes) {
    node := scene.nodes[j]
    load_node(v, node) or_return
  }

  return nil
}

loop :: proc(v: ^vk.Vulkan_Context, w: ^wl.Wayland_Context) -> error.Error {
  ctx: Context
  ctx.wl = w

  ctx.view = matrix[4, 4]f32{
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, -20,
    0, 0, 0, 1,
  }

  angle_velocity: f32 = 3.14 / 32
  translation_velocity: f32 = 2

  vk.update_view(v, ctx.view)
  vk.update_light(v, {0, 0, 0})

  ctx.rotate_up = linalg.matrix4_rotate_f32(angle_velocity, [3]f32{1, 0, 0})
  ctx.rotate_down = linalg.matrix4_rotate_f32(angle_velocity, [3]f32{-1, 0, 0})
  ctx.rotate_left = linalg.matrix4_rotate_f32(angle_velocity, [3]f32{0, -1, 0})
  ctx.rotate_right = linalg.matrix4_rotate_f32(angle_velocity, [3]f32{0, 1, 0})
  ctx.translate_right = linalg.matrix4_translate_f32({translation_velocity, 0, 0})
  ctx.translate_left = linalg.matrix4_translate_f32({-translation_velocity, 0, 0})
  ctx.translate_back = linalg.matrix4_translate_f32({0, 0, -translation_velocity / 4})
  ctx.translate_for = linalg.matrix4_translate_f32({0, 0, translation_velocity / 4})

  {
    mark := mem.begin_arena_temp_memory(v.tmp_arena)
    defer mem.end_arena_temp_memory(mark)
    load_gltf(v, "assets/bone.gltf") or_return
    // collection.vec_append(&ctx.gltfs, gltf)
    // add_instance(v, &ctx.gltfs.data[0].nodes[0], matrix[4, 4]f32{1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1}, vk.Color{ 0, 1, 0, 1 })
  }
  // {
  //   mark := mem.begin_arena_temp_memory(v.tmp_arena)
  //   defer mem.end_arena_temp_memory(mark)
  //   gltf := load_gltf(v, "assets/cube_animation.gltf", matrix[4, 4]f32{ 1, 0, 0, 3, 0, 1, 0, 0, 0, 0, 1, 0,  0, 0, 0, 1,  }, vk.Color{0.0, 1.0, 0.0, 1.0}) or_return
  //   collection.vec_append(&ctx.gltfs, gltf)
  // }

  // {
  //   mark := mem.begin_arena_temp_memory(v.tmp_arena)
  //   defer mem.end_arena_temp_memory(mark)
  //   gltf := load_gltf(v, "assets/monkey.gltf", matrix[4, 4]f32{ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0,  0, 0, 0, 1,  }, vk.Color{1.0, 0.0, 0.0, 1.0}) or_return
  //   collection.vec_append(&ctx.gltfs, gltf)
  // }

  // {
  //   mark := mem.begin_arena_temp_memory(v.tmp_arena)
  //   defer mem.end_arena_temp_memory(mark)
  //   gltf := load_gltf(v, "assets/cone.gltf", matrix[4, 4]f32{ 1, 0, 0, -3, 0, 1, 0, 0, 0, 0, 1, 0,  0, 0, 0, 1,  }, vk.Color{0.0, 0.0, 1.0, 1.0}) or_return
  //   collection.vec_append(&ctx.gltfs, gltf)
  // }

  // {
  //   mark := mem.begin_arena_temp_memory(v.tmp_arena)
  //   defer mem.end_arena_temp_memory(mark)
  //   gltf := load_gltf(v, "assets/plane.gltf", matrix[4, 4]f32{ 20, 0, 0, -0, 0, 1, 0, -2, 0, 0, 20, 0,  0, 0, 0, 1,  }, vk.Color{1.0, 1.0, 1.0, 1.0}) or_return
  //   collection.vec_append(&ctx.gltfs, gltf)
  // }

  wl.add_listener(w, &ctx, frame)

  for w.running {
    mark := mem.begin_arena_temp_memory(v.tmp_arena)
    defer mem.end_arena_temp_memory(mark)

//    now := time.now()._nsec
//    for &animation in ctx.current_animations.data[0:ctx.current_animations.len] {
//      play_animation(v, &ctx, &animation, now) or_return
//    }

    if wl.render(w) != nil {
      log.error("Failed to render frame")
    }
  }

  return nil
}

// play_animation :: proc(v: ^vk.Vulkan_Context, ctx: ^Context, animation: ^Animation, now: i64, id: u32) -> error.Error {
//   frame, index, repeat, finished := gltf.get_animation_frame(animation.handle, f32(now - animation.start) / 1_000_000_000, animation.frame)
//   animation.frame = index

//   if repeat {
//     return nil
//   }

//   if finished {
//     ctx.current_animations.len = 0
//     return nil
//   }

//   for i in animation.handle.nodes {
//     vk.instance_update(v, animation.gltf.nodes[i].instances.data[id].id, frame.transforms[i] * animation.gltf.nodes[i].transform, nil) or_return
//   }

//   return nil
// }

frame :: proc(ptr: rawptr, keymap: ^wl.Keymap_Context) -> error.Error {
  ctx := cast(^Context)(ptr)
  view_update := false

  if wl.is_key_pressed(keymap, .ArrowRight) {
    ctx.view = ctx.translate_left * ctx.view
    view_update = true
  }

  if wl.is_key_pressed(keymap, .ArrowLeft) {
    ctx.view = ctx.translate_right * ctx.view
    view_update = true
  }

  if wl.is_key_pressed(keymap, .ArrowDown) {
    ctx.view = ctx.translate_back * ctx.view
    view_update = true
  }

  if wl.is_key_pressed(keymap, .ArrowUp) {
    ctx.view = ctx.translate_for * ctx.view
    view_update = true
  }

  if wl.is_key_pressed(keymap, .a) {
    ctx.view = ctx.rotate_up * ctx.view
    view_update = true
  }

  // if wl.is_key_pressed(keymap, .Space) {
  //   if ctx.current_animations.len == 0 {
  //     animation: Animation

  //     animation.gltf = &ctx.gltfs.data[0]
  //     animation.handle = &ctx.gltfs.data[0].handle.animations["CubeAction"]
  //     animation.frame = 0
  //     animation.start = time.now()._nsec

  //     collection.vec_append(&ctx.current_animations, animation) or_return
  //   }
  // }

  if view_update {
    vk.update_view(ctx.wl.vk, ctx.view) or_return
  }

  return nil
}
