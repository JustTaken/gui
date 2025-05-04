package main

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:math/linalg"
import "core:log"

import collection "collection"
import vk "vulkan"
import wl "wayland"

Context :: struct {
  instances: collection.Vector(u32),
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

  if bytes, err = make([]u8, 1024 * 1024 * 2, context.allocator); err != nil {
    fmt.println("Error:", err)
    return
  }

  defer delete(bytes)

  mem.arena_init(&arena, bytes)
  context.allocator = mem.arena_allocator(&arena)

  mem.arena_init(&tmp_arena, make([]u8, 1024 * 1024 * 1, context.allocator))
  context.temp_allocator = mem.arena_allocator(&tmp_arena)

  if !init(&v, &w, width, height, frames, &arena, &tmp_arena) {
    fmt.println("Error:", err)
    return
  }

  if loop(&v, &w) != nil {
    fmt.println("Error:", err)
    return
  }

  wl.deinit_wayland(&w)
  vk.deinit_vulkan(&v)

  fmt.println("TMP", tmp_arena.offset, tmp_arena.peak_used)
  fmt.println("MAIN", arena.offset - len(tmp_arena.data), arena.peak_used - len(tmp_arena.data))
}

init :: proc(v: ^vk.Vulkan_Context, w: ^wl.Wayland_Context, width: u32, height: u32, frames: u32, arena: ^mem.Arena, tmp_arena: ^mem.Arena) -> bool {
    vulkan_ok := vk.init_vulkan(v, width, height, frames, arena, tmp_arena) == nil
    wayland_ok := wl.init_wayland(w, v, width, height, frames, arena, tmp_arena) == nil

    return vulkan_ok && wayland_ok
}

load_meshs :: proc(v: ^vk.Vulkan_Context, path: string, models: []vk.InstanceModel, colors: []vk.Color) -> (ids: []u32, err: vk.Error) {
  g_err: collection.Error
  gltf: collection.Gltf

  l := len(models)
  assert(l == len(colors))

  ids = make([]u32, l, v.tmp_allocator)

  if gltf, g_err = collection.gltf_from_file(path, v.tmp_allocator); g_err != nil {
    return ids, .ReadFileFailed
  }
  node := &gltf.scenes["Scene"].nodes[0]
  mesh := &node.mesh

  positions := collection.get_mesh_attribute(mesh, .Position)
  normals := collection.get_mesh_attribute(mesh, .Normal)
  textures := collection.get_mesh_attribute(mesh, .Texture0)
  indices := collection.get_mesh_indices(mesh)

  vertices := collection.get_vertex_data({positions, normals, textures}, v.tmp_allocator)
  id := vk.geometry_create(v, vertices.bytes, vertices.size, vertices.count, indices.bytes, indices.size, indices.count, u32(l)) or_return

  for i in 0..<l {
    ids[i] = vk.geometry_instance_add(v, id, models[i] * node.transform, colors[i]) or_return
  }

  return ids, nil
}

loop :: proc(v: ^vk.Vulkan_Context, w: ^wl.Wayland_Context) -> vk.Error {
  ctx: Context
  ctx.wl = w
  ctx.instances = collection.new_vec(u32, 20, v.allocator)
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
    monkeys := load_meshs(v, "assets/monkey.gltf",
      {matrix[4, 4]f32{
          1, 0, 0, 0,
          0, 1, 0, 0,
          0, 0, 1, 0, 
          0, 0, 0, 1, 
      }},
      {vk.Color{1.0, 0.0, 0.0, 1.0}},
    ) or_return

    collection.vec_append_n(&ctx.instances, monkeys)
  }

  {
    mark := mem.begin_arena_temp_memory(v.tmp_arena)
    defer mem.end_arena_temp_memory(mark)
    cubes := load_meshs(v, "assets/cube_animation.gltf",
      {matrix[4, 4]f32{
          1, 0, 0, 3,
          0, 1, 0, 0,
          0, 0, 1, 0, 
          0, 0, 0, 1, 
      }},
      {vk.Color{0.0, 1.0, 0.0, 1.0}},
    ) or_return

    collection.vec_append_n(&ctx.instances, cubes)
  }

  {
    mark := mem.begin_arena_temp_memory(v.tmp_arena)
    defer mem.end_arena_temp_memory(mark)
    cones := load_meshs(v, "assets/cone.gltf",
      {matrix[4, 4]f32{
          1, 0, 0, -3,
          0, 1, 0, 0,
          0, 0, 1, 0, 
          0, 0, 0, 1, 
      }},
      {vk.Color{0.0, 0.0, 1.0, 1.0}},
    ) or_return

    collection.vec_append_n(&ctx.instances, cones)
  }

  {
    mark := mem.begin_arena_temp_memory(v.tmp_arena)
    defer mem.end_arena_temp_memory(mark)
    planes := load_meshs(v, "assets/plane.gltf",
      {matrix[4, 4]f32{
          20, 0, 0, -0,
          0, 1, 0, -2,
          0, 0, 20, 0, 
          0, 0, 0, 1, 
      }},
      {vk.Color{1.0, 1.0, 1.0, 1.0}},
    ) or_return

    collection.vec_append_n(&ctx.instances, planes)
  }

  wl.add_listener(w, &ctx, frame)

  for w.running {
    mark := mem.begin_arena_temp_memory(v.tmp_arena)
    defer mem.end_arena_temp_memory(mark)

    if wl.render(w) != nil {
      fmt.println("Failed to render frame")
    }
  }

  return nil
}

frame :: proc(ptr: rawptr, keymap: ^wl.Keymap_Context) {
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

  if view_update {
    if vk.update_view(ctx.wl.vk, ctx.view) != nil {
      fmt.println("FAILED TO UPDATE VIEW")
    }
  }
}
