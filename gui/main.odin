package main

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:math/linalg"

import collection "collection"
import vk "vulkan"
import wl "wayland"

Error :: enum {
  OutOfMemory,
  OutOfStagingMemory,
  FileNotFound,
  ReadFileFailed,
  AttributeKindNotFound,
  NumberParseFailed,
  CreateInstanceFailed,
  CreateBuffer,
  BeginCommandBufferFailed,
  EndCommandBufferFailed,
  AllocateCommandBufferFailed,
  VulkanLib,
  LayerNotFound,
  PhysicalDeviceNotFound,
  FamilyIndiceNotComplete,
  MemoryNotFound,
  EnviromentVariablesNotSet,
  WaylandSocketNotAvaiable,
  SendMessageFailed,
  BufferNotReleased,
  CreateDescriptorSetLayoutFailed,
  CreatePipelineFailed,
  GetImageModifier,
  AllocateDeviceMemory,
  CreateImageFailed,
  WaitFencesFailed,
  QueueSubmitFailed,
  CreateImageViewFailed,
  CreatePipelineLayouFailed,
  CreateDescriptorPoolFailed,
  CreateFramebufferFailed,
  GetFdFailed,
  SizeNotMatch,
  CreateShaderModuleFailed,
  AllocateDescriptorSetFailed,
  ExtensionNotFound,
  CreateDeviceFailed,
  CreateRenderPassFailed,
  CreateSemaphoreFailed,
  CreateFenceFailed,
  CreateCommandPoolFailed,
  SocketConnectFailed,
  GltfLoadFailed,
  InvalidKeymapInput,
  TypeAssertionFailed,
  IdentifierAssertionFailed,
  KeywordAssertionFailed,
  SymbolAssertionFailed,
  InvalidToken,
  CodeNotFound,
  ModifierNotFound,
  UnregisteredKey,
  NotANumber,
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

  if loop(&v, &w, &arena, &tmp_arena) != nil {
    fmt.println("Error:", err)
    return
  }

  wl.deinit_wayland(&w)
  vk.deinit_vulkan(&v)

  fmt.println("TMP", tmp_arena.offset, tmp_arena.peak_used)
  fmt.println("MAIN", arena.offset - len(tmp_arena.data), arena.peak_used - len(tmp_arena.data))
}

init :: proc(v: ^vk.Vulkan_Context, w: ^wl.Wayland_Context, width: u32, height: u32, frames: u32, arena: ^mem.Arena, tmp_arena: ^mem.Arena) -> bool {
    vulkan_ok := vk.init_vulkan(v, 1920, 1080, frames, arena, tmp_arena) == nil
    wayland_ok := wl.init_wayland(w, v, width, height, frames, arena, tmp_arena) == nil

    return vulkan_ok && wayland_ok
}

loop :: proc(v: ^vk.Vulkan_Context, w: ^wl.Wayland_Context, arena: ^mem.Arena, tmp_arena: ^mem.Arena) -> vk.Error {
  err: collection.Error
  monkey: collection.Mesh

  if monkey, err = collection.gltf_from_file("assets/monkey.gltf", v.tmp_allocator); err != nil {
    return .ReadFileFailed
  }

  count := u32(len(monkey.position.([][3]f32)))
  vertices := make([]vk.Vertex, count, v.tmp_allocator)
  indices := monkey.indice.([]u16)

  {
    positions := monkey.position.([][3]f32)
    normals := monkey.normal.([][3]f32)
    textures := monkey.texture.([][2]f32)

    for i in 0 ..< count {
      vertices[i] = vk.Vertex {
        position = positions[i],
        normal   = normals[i],
        texture  = textures[i],
      }
    }
  }

  angle_velocity: f32 = 3.14 / 32
  immaculated_view := matrix[4, 4]f32{
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
  }

  width := f32(1)
  height := f32(1)
  translation_velocity: f32 = 0.5
  widget_model := matrix[4, 4]f32{
    width, 0, 0, 0, 
    0, height, 0, 0, 
    0, 0, 1, -1, 
    0, 0, 0, 1, 
  }

  view := immaculated_view

  color := vk.Color{1.0, 0.0, 0.0, 1.0}

  vk.update_view(v, view)
  vk.update_light(v, {0, 0, 0})

  geometry := vk.geometry_create(v, vertices, indices, 4) or_return
  widget := vk.widget_create(v, geometry, widget_model, color, 3) or_return

  rotate_up := linalg.matrix4_rotate_f32(angle_velocity, [3]f32{1, 0, 0})
  rotate_down := linalg.matrix4_rotate_f32(angle_velocity, [3]f32{-1, 0, 0})
  rotate_left := linalg.matrix4_rotate_f32(angle_velocity, [3]f32{0, -1, 0})
  rotate_right := linalg.matrix4_rotate_f32(angle_velocity, [3]f32{0, 1, 0})

  translate_right := linalg.matrix4_translate_f32({translation_velocity, 0, 0})
  translate_left := linalg.matrix4_translate_f32({-translation_velocity, 0, 0})
  translate_back := linalg.matrix4_translate_f32({0, 0, -translation_velocity / 4})
  translate_for := linalg.matrix4_translate_f32({0, 0, translation_velocity / 4})

  for w.running {
    mark := mem.begin_arena_temp_memory(tmp_arena)
    defer mem.end_arena_temp_memory(mark)

    model_update := false
    view_update := false

    if wl.is_key_pressed(&w.keymap, .w) {
      widget_model = widget_model * rotate_up
      model_update = true
    }

    if wl.is_key_pressed(&w.keymap, .ArrowRight) {
      view = translate_left * view
      view_update = true
    }

    if wl.is_key_pressed(&w.keymap, .ArrowLeft) {
      view = translate_right * view
      view_update = true
    }

    if wl.is_key_pressed(&w.keymap, .ArrowDown) {
      view = translate_back * view
      view_update = true
    }

    if wl.is_key_pressed(&w.keymap, .ArrowUp) {
      view = translate_for * view
      view_update = true
    }

    if wl.is_key_pressed(&w.keymap, .r) {
      view = immaculated_view
      view_update = true
    }

    if wl.is_key_pressed(&w.keymap, .a) {
      view = rotate_up * view
      view_update = true
    }

    if view_update {
      vk.update_view(v, view) or_return
    }

    if model_update {
      vk.widget_update(v, widget, widget_model, nil) or_return
    }

    if wl.render(w) != nil {
      fmt.println("Failed to render frame")
    }
  }

  return nil
}
