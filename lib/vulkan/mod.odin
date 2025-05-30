package vulk

import "base:runtime"
import "core:dynlib"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:sys/posix"
import vk "vendor:vulkan"

import "lib:collection/vector"
import "lib:error"

library: dynlib.Library

@(private)
VALIDATION_LAYERS := [?]cstring{"VK_LAYER_KHRONOS_validation"}

@(private)
DEVICE_EXTENSIONS := [?]cstring {
  "VK_KHR_external_memory_fd",
  "VK_EXT_external_memory_dma_buf",
  "VK_EXT_image_drm_format_modifier",
}

Vulkan_Context :: struct {
  instance:         vk.Instance,
  device:           Device,
  physical_device:  vk.PhysicalDevice,
  set_layouts:      vector.Vector(Descriptor_Set_Layout),
  geometries:       vector.Vector(Geometry),
  materials:        vector.Vector(Material),
  default_material: u32,
  render_pass:      Render_Pass,
  descriptor_pool:  Descriptor_Pool,
  fixed_set:        ^Descriptor_Set,
  dynamic_set:      ^Descriptor_Set,
  default_pipeline: ^Pipeline,
  plain_pipeline:   ^Pipeline,
  boned_pipeline:   ^Pipeline,
  instances:        u32,
  transforms:       u32,
  command_pool:     vk.CommandPool,
  command_buffers:  vector.Vector(vk.CommandBuffer),
  staging:          StagingBuffer,
  frames:           vector.Vector(Frame),
  copy_fence:       vk.Fence,
  draw_fence:       vk.Fence,
  semaphore:        vk.Semaphore,
  format:           vk.Format,
  depth_format:     vk.Format,
  modifiers:        vector.Vector(vk.DrmFormatModifierPropertiesEXT),
  arena:            ^mem.Arena,
  allocator:        runtime.Allocator,
  tmp_arena:        ^mem.Arena,
  tmp_allocator:    runtime.Allocator,
}

vulkan_init :: proc(
  ctx: ^Vulkan_Context,
  width: u32,
  height: u32,
  frame_count: u32,
  arena: ^mem.Arena,
  tmp_arena: ^mem.Arena,
) -> error.Error {
  log.info("Initializing Vulkan")

  mark := mem.begin_arena_temp_memory(tmp_arena)
  defer mem.end_arena_temp_memory(mark)

  ctx.arena = arena
  ctx.allocator = mem.arena_allocator(arena)

  ctx.tmp_arena = tmp_arena
  ctx.tmp_allocator = mem.arena_allocator(tmp_arena)

  if lib, ok := dynlib.load_library("libvulkan.so", allocator = ctx.allocator);
     ok {
    library = lib
    vk.load_proc_addresses_custom(load_fn)
  } else {
    return .VulkanLib
  }

  ctx.format = .B8G8R8A8_SRGB
  ctx.depth_format = .D32_SFLOAT_S8_UINT

  ctx.instance = create_instance(ctx) or_return
  ctx.physical_device = find_physical_device(ctx) or_return
  ctx.modifiers = get_drm_modifiers(ctx) or_return
  ctx.device = device_create(ctx) or_return

  ctx.draw_fence = fence_create(ctx) or_return
  ctx.copy_fence = fence_create(ctx) or_return
  ctx.semaphore = semaphore_create(ctx) or_return

  ctx.command_pool = command_pool_create(ctx, ctx.device.queues[1]) or_return

  ctx.command_buffers = command_buffers_allocate(
    ctx,
    ctx.command_pool,
    2,
  ) or_return

  ctx.staging.buffer = buffer_create(
    ctx,
    size_of(Matrix) * 256 * 1000,
    {.TRANSFER_SRC},
    {.HOST_COHERENT, .HOST_VISIBLE},
  ) or_return

  ctx.set_layouts = vector.new(
    Descriptor_Set_Layout,
    20,
    ctx.allocator,
  ) or_return

  ctx.geometries = vector.new(Geometry, 20, ctx.allocator) or_return
  ctx.materials = vector.new(Material, 20, ctx.allocator) or_return
  ctx.descriptor_pool = descriptor_pool_create(
    ctx,
    {
      {type = .UNIFORM_BUFFER, descriptorCount = 20},
      {type = .STORAGE_BUFFER, descriptorCount = 20},
    },
    20,
  ) or_return

  ctx.render_pass = render_pass_create(ctx) or_return

  fixed_set_layout := set_layout_create(
    ctx,
    {
      binding_create(
        .UNIFORM_BUFFER,
        1,
        {.VERTEX},
        .UNIFORM_BUFFER,
        {.UNIFORM_BUFFER, .TRANSFER_DST},
        {.DEVICE_LOCAL},
        size_of(Matrix),
      ),
      binding_create(
        .STORAGE_BUFFER,
        1,
        {.VERTEX},
        .STORAGE_BUFFER,
        {.STORAGE_BUFFER, .TRANSFER_DST},
        {.DEVICE_LOCAL},
        size_of(Light),
      ),
    },
  ) or_return

  ctx.fixed_set = descriptor_set_allocate(
    ctx,
    &ctx.descriptor_pool,
    fixed_set_layout,
    {2, 1},
  ) or_return

  dynamic_set_layout := set_layout_create(
    ctx,
    {
      binding_create(
        .STORAGE_BUFFER,
        1,
        {.VERTEX},
        .STORAGE_BUFFER,
        {.STORAGE_BUFFER, .TRANSFER_DST},
        {.DEVICE_LOCAL},
        size_of(Material),
      ),
      binding_create(
        .STORAGE_BUFFER,
        1,
        {.VERTEX},
        .STORAGE_BUFFER,
        {.STORAGE_BUFFER, .TRANSFER_DST},
        {.DEVICE_LOCAL},
        size_of(Instance_Model),
      ),
      binding_create(
        .STORAGE_BUFFER,
        1,
        {.VERTEX},
        .STORAGE_BUFFER,
        {.STORAGE_BUFFER, .TRANSFER_DST},
        {.DEVICE_LOCAL},
        size_of(Matrix),
      ),
      binding_create(
        .STORAGE_BUFFER,
        1,
        {.VERTEX},
        .STORAGE_BUFFER,
        {.STORAGE_BUFFER, .TRANSFER_DST},
        {.DEVICE_LOCAL},
        size_of(u32),
      ),
      binding_create(
        .STORAGE_BUFFER,
        1,
        {.VERTEX},
        .STORAGE_BUFFER,
        {.STORAGE_BUFFER, .TRANSFER_DST},
        {.DEVICE_LOCAL},
        size_of(u32),
      ),
    },
  ) or_return

  ctx.dynamic_set = descriptor_set_allocate(
    ctx,
    &ctx.descriptor_pool,
    dynamic_set_layout,
    {50, 50, 50, 50, 50},
  ) or_return

  layout := render_pass_append_layout(
    &ctx.render_pass,
    layout_create(ctx, {fixed_set_layout, dynamic_set_layout}) or_return,
  ) or_return

  unboned_shader := render_pass_append_shader(
    ctx,
    &ctx.render_pass,
    "assets/output/unboned.spv",
  ) or_return

  boned_shader := render_pass_append_shader(
    ctx,
    &ctx.render_pass,
    "assets/output/boned.spv",
  ) or_return

  plain_shader := render_pass_append_shader(
    ctx,
    &ctx.render_pass,
    "assets/output/plain.spv",
  ) or_return

  fragment_shader := render_pass_append_shader(
    ctx,
    &ctx.render_pass,
    "assets/output/frag.spv",
  ) or_return

  defer {
    shader_module_destroy(ctx, unboned_shader)
    shader_module_destroy(ctx, boned_shader)
    shader_module_destroy(ctx, plain_shader)
    shader_module_destroy(ctx, fragment_shader)
  }

  ctx.default_pipeline = render_pass_append_pipeline(
    ctx,
    &ctx.render_pass,
    layout,
    unboned_shader,
    fragment_shader,
    {{{.Sfloat, 3}, {.Sfloat, 3}, {.Sfloat, 2}}},
  ) or_return

  ctx.plain_pipeline = render_pass_append_pipeline(
    ctx,
    &ctx.render_pass,
    layout,
    plain_shader,
    fragment_shader,
    {{{.Sfloat, 3}, {.Sfloat, 3}, {.Sfloat, 2}}},
  ) or_return

  ctx.boned_pipeline = render_pass_append_pipeline(
    ctx,
    &ctx.render_pass,
    layout,
    boned_shader,
    fragment_shader,
    {{{.Sfloat, 3}, {.Sfloat, 3}, {.Sfloat, 2}, {.Sfloat, 4}, {.Uint, 4}}},
  ) or_return

  ctx.frames = frames_create(
    ctx,
    &ctx.render_pass,
    frame_count,
    width,
    height,
  ) or_return

  ctx.default_material = material_create(
    ctx,
    Material{0, 0.8, 0.2, 1},
  ) or_return

  return nil
}

vulkan_deinit :: proc(ctx: ^Vulkan_Context) {
  vk.WaitForFences(ctx.device.handle, 1, &ctx.draw_fence, true, 0xFFFFFF)
  vk.WaitForFences(ctx.device.handle, 1, &ctx.copy_fence, true, 0xFFFFFF)

  buffer_destroy(ctx, ctx.staging.buffer)

  vk.DestroySemaphore(ctx.device.handle, ctx.semaphore, nil)
  vk.DestroyFence(ctx.device.handle, ctx.draw_fence, nil)
  vk.DestroyFence(ctx.device.handle, ctx.copy_fence, nil)

  for i in 0 ..< ctx.frames.len {
    frame_destroy(ctx, &ctx.frames.data[i])
  }

  for i in 0 ..< ctx.set_layouts.len {
    vk.DestroyDescriptorSetLayout(
      ctx.device.handle,
      ctx.set_layouts.data[i].handle,
      nil,
    )
  }

  for i in 0 ..< ctx.geometries.len {
    destroy_geometry(ctx, &ctx.geometries.data[i])
  }

  descriptor_pool_deinit(ctx, ctx.descriptor_pool)
  render_pass_deinit(ctx, &ctx.render_pass)

  vk.DestroyCommandPool(ctx.device.handle, ctx.command_pool, nil)
  vk.DestroyDevice(ctx.device.handle, nil)
  vk.DestroyInstance(ctx.instance, nil)

  _ = dynlib.unload_library(library)
}

@(private)
load_fn :: proc(ptr: rawptr, name: cstring) {
  (cast(^rawptr)ptr)^ = dynlib.symbol_address(library, string(name))
}
