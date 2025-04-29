package main

import "base:runtime"
import "core:fmt"
import "core:mem"

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

init :: proc(
    v: ^vk.Vulkan_Context,
    w: ^wl.Wayland_Context,
    width: u32,
    height: u32,
    frames: u32,
    arena: ^mem.Arena,
    tmp_arena: ^mem.Arena,
) -> bool {
    vulkan_ok := vk.init_vulkan(v, 1920, 1080, frames, arena, tmp_arena) == nil
    wayland_ok := wl.init_wayland(w, v, width, height, frames, arena, tmp_arena) == nil

    return vulkan_ok && wayland_ok
}

loop :: proc(v: ^vk.Vulkan_Context, w: ^wl.Wayland_Context, arena: ^mem.Arena, tmp_arena: ^mem.Arena) -> vk.Error {
  err: collection.Error
  monkey: collection.Mesh

  velocity: f32 = 50
  view := matrix[4, 4]f32{
    1, 0, 0, -100,
    0, 1, 0, -100,
    0, 0, 1, 10,
    0, 0, 0, 1,
  }

  vk.update_view(v, view)
  vk.update_light(v, {0, 0, 0})

  if monkey, err = collection.gltf_from_file("assets/monkey.gltf", v.tmp_allocator); err != nil {
    return .ReadFileFailed
  }

  count := u32(len(monkey.position.([][3]f32)))
  vertices := make([]vk.Vertex, count, v.tmp_allocator)
  indices := monkey.indice.([]u16)

  // fmt.println("Normals:", monkey.normal)

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

  width := f32(400)
  height := f32(400)
  model := matrix[4, 4]f32{
    width, 0, 0, width * 2, 
    0, height, 0, -height * 2, 
    0, 0, 1, 1, 
    0, 0, 0, 1, 
  }

  widget_model := model

  color := vk.Color{1.0, 0.0, 0.0, 1.0}

  // model1 := matrix[4, 4]f32{
  //      300, 0, 0, 100, 
  //      0, 50, 0, -50, 
  //      0, 0, 1, 0, 
  //      0, 0, 0, 1, 
  // }

  // model2 := matrix[4, 4]f32{
  //      300, 0, 0, 100, 
  //      0, 50, 0, -(50 + 5) * 2 - 50, 
  //      0, 0, 1, 0, 
  //      0, 0, 0, 1, 
  // }

  // model3 := matrix[4, 4]f32{
  //      300, 0, 0, 100, 
  //      0, 50, 0, -(50 + 5) * 4 - 50, 
  //      0, 0, 1, 0, 
  //      0, 0, 0, 1, 
  // }

  // color1 := Color{1.0, 1.0, 1.0, 1.0}
  // color2 := Color{0.0, 0.0, 1.0, 1.0}
  // color3 := Color{1.0, 0.0, 1.0, 1.0}

  geometry := vk.geometry_create(v, vertices, indices, 4) or_return
  widget := vk.widget_create(v, geometry, widget_model, color, 3) or_return

  // instance1 := widget_add_child(vk, widget, geometry, model1, color1) or_return
  // instance2 := widget_add_child(vk, widget, geometry, model2, color2) or_return
  // instance3 := widget_add_child(vk, widget, geometry, model3, color3) or_return

  i: i32 = 0

  for w.running {
    mark := mem.begin_arena_temp_memory(tmp_arena)
    defer mem.end_arena_temp_memory(mark)

    if wl.is_key_pressed(&w.keymap, .j) {
      view[2, 3] += 0.1
      vk.update_view(v, view) or_return
    }

    if wl.is_key_pressed(&w.keymap, .k) {
      view[2, 3] -= 0.1
      vk.update_view(v, view) or_return
    }

    if wl.is_key_pressed(&w.keymap, .l) {
      view[0, 3] -= velocity
      vk.update_view(v, view) or_return
    }

    if wl.is_key_pressed(&w.keymap, .h) {
      view[0, 3] += velocity
      vk.update_view(v, view) or_return
    }

    if wl.render(w) != nil {
      fmt.println("Failed to render frame")
    }

    i += 20
  }

  return nil
}
