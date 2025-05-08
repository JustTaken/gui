package main

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:math/linalg"
import "core:log"
import "core:time"

import collection "collection"
import vk "vulkan"
import wl "wayland"
import "error"

Context :: struct {
  gltfs: collection.Vector(Gltf),
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
  current_animations: collection.Vector(Animation)
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
    return
  }

  if e := loop(&v, &w); e != nil {
    fmt.println("Could not complete loop due to error:", e)
    return
  }

  wl.deinit_wayland(&w)
  vk.deinit_vulkan(&v)

  fmt.println("TMP", tmp_arena.offset, tmp_arena.peak_used)
  fmt.println("MAIN", arena.offset - len(tmp_arena.data), arena.peak_used - len(tmp_arena.data))
}

init :: proc(v: ^vk.Vulkan_Context, w: ^wl.Wayland_Context, width: u32, height: u32, frames: u32, arena: ^mem.Arena, tmp_arena: ^mem.Arena) -> bool {
    if err := vk.init_vulkan(v, width, height, frames, arena, tmp_arena); err != nil {
      fmt.println("Failed to Initialize vulkan due to:", err)
      return false
    }

    if err := wl.init_wayland(w, v, width, height, frames, arena, tmp_arena); err != nil {
      fmt.println("Failed to initialize Wayland due to:", err)
      return false
    }

    fmt.println("Successfully initialized environment")

    return true
}

Gltf :: struct {
  handle: collection.Gltf,
  nodes: []Node,
}

Animation :: struct {
  handle: ^collection.Gltf_Animation,
  gltf: ^Gltf,
  frame: u32,
  start: i64,
}

Node_Instance :: struct {
  transform: matrix[4, 4]f32,
  id: u32,
}

Node :: struct {
  instances: collection.Vector(Node_Instance),
  geometry: u32,
  transform: matrix[4, 4]f32,
}

load_gltf :: proc(v: ^vk.Vulkan_Context, path: string) -> (gltf: Gltf, err: error.Error) {
  gltf.handle = collection.gltf_from_file(path, v.allocator, v.tmp_allocator) or_return
  scene := &gltf.handle.scenes["Scene"]

  gltf.nodes = make([]Node, len(scene.all_nodes), v.allocator)

  for j in 0..<len(scene.all_nodes) {
    scene_node := &scene.all_nodes[j]

    if m := scene_node.mesh; m != nil {
      mesh := &m.?
      // positions := collection.get_mesh_accessor(mesh, .Position)
      // normals := collection.get_mesh_accessor(mesh, .Normal)
      // textures := collection.get_mesh_accessor(mesh, .Texture0)
      indices := collection.get_mesh_indices(mesh)

      vertices := collection.get_vertex_data({.Position, .Normal, .Texture0}, v.tmp_allocator)
      id := vk.geometry_create(v, vertices.bytes, vertices.size, vertices.count, indices.bytes, indices.size, indices.count, 1) or_return

      gltf.nodes[j].geometry = id
      gltf.nodes[j].instances = collection.new_vec(Node_Instance, 10, v.allocator) or_return
      gltf.nodes[j].transform = scene_node.transform
    }
  }

  return gltf, nil
}

add_instance :: proc(v: ^vk.Vulkan_Context, node: ^Node, model: vk.InstanceModel, color: vk.Color) -> error.Error {
  instance: Node_Instance
  collection.vec_append(&node.instances, instance)

  instance.transform = model * node.transform
  instance.id = vk.geometry_instance_add(v, node.geometry, instance.transform, color) or_return

  return nil
}

loop :: proc(v: ^vk.Vulkan_Context, w: ^wl.Wayland_Context) -> error.Error {
  ctx: Context
  ctx.wl = w
  ctx.gltfs = collection.new_vec(Gltf, 20, v.allocator) or_return
  ctx.current_animations = collection.new_vec(Animation, 20, v.allocator) or_return
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
    gltf := load_gltf(v, "assets/cube_animation.gltf") or_return
    collection.vec_append(&ctx.gltfs, gltf)
    add_instance(v, &ctx.gltfs.data[0].nodes[0], matrix[4, 4]f32{1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1}, vk.Color{ 0, 1, 0, 1 })
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
      fmt.println("Failed to render frame")
    }
  }

  return nil
}

play_animation :: proc(v: ^vk.Vulkan_Context, ctx: ^Context, animation: ^Animation, now: i64, id: u32) -> error.Error {
  frame, index, repeat, finished := collection.get_animation_frame(animation.handle, f32(now - animation.start) / 1_000_000_000, animation.frame)
  animation.frame = index

  if repeat {
    return nil
  }

  if finished {
    ctx.current_animations.len = 0
    return nil
  }

  for i in animation.handle.nodes {
    vk.instance_update(v, animation.gltf.nodes[i].instances.data[id].id, frame.transforms[i] * animation.gltf.nodes[i].transform, nil) or_return
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

  if wl.is_key_pressed(keymap, .Space) {
    if ctx.current_animations.len == 0 {
      animation: Animation

      animation.gltf = &ctx.gltfs.data[0]
      animation.handle = &ctx.gltfs.data[0].handle.animations["CubeAction"]
      animation.frame = 0
      animation.start = time.now()._nsec

      // fmt.println("Playing animation, Frame count", len(animation.handle.frames), "Node count:", len(animation.gltf.nodes))

      collection.vec_append(&ctx.current_animations, animation)
    }
  }

  if view_update {
    if vk.update_view(ctx.wl.vk, ctx.view) != nil {
      fmt.println("FAILED TO UPDATE VIEW")
    }
  }
}
