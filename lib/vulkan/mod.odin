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
  instance:                vk.Instance,
  device:                  Device,
  draw_queue:              ^Queue,
  transfer_queue:          ^Queue,
  physical_device:         vk.PhysicalDevice,
  copy_fence:              vk.Fence,
  draw_fence:              vk.Fence,
  semaphore:               vk.Semaphore,
  format:                  vk.Format,
  depth_format:            vk.Format,
  render_passes:           vector.Vector(Render_Pass),
  set_layouts:             vector.Vector(Descriptor_Set_Layout),
  shaders:                 vector.Vector(Shader_Module),
  geometries:              vector.Vector(Geometry),
  materials:               vector.Vector(Material),
  images:                  vector.Vector(Image),
  buffers:                 vector.Vector(Buffer),
  descriptor_pools:        vector.Vector(Descriptor_Pool),
  pipeline_layouts:        vector.Vector(Pipeline_Layout),
  writes:                  vector.Vector(vk.WriteDescriptorSet),
  infos:                   vector.Vector(vk.DescriptorBufferInfo),
  frames:                  vector.Vector(Frame),
  modifiers:               vector.Vector(vk.DrmFormatModifierPropertiesEXT),
  render_pass:             ^Render_Pass,
  default_pipeline:        ^Pipeline,
  plain_pipeline:          ^Pipeline,
  boned_pipeline:          ^Pipeline,
  staging:                 ^Buffer,
  projection:              ^Buffer,
  light:                   ^Buffer,
  material_buffer:         ^Buffer,
  model_buffer:            ^Buffer,
  transform_buffer:        ^Buffer,
  transform_offset_buffer: ^Buffer,
  material_offset_buffer:  ^Buffer,
  descriptor_pool:         ^Descriptor_Pool,
  fixed_set:               ^Descriptor_Set,
  dynamic_set:             ^Descriptor_Set,
  draw_command_pool:       ^Command_Pool,
  transfer_command_pool:   ^Command_Pool,
  draw_command_buffer:     ^Command_Buffer,
  transfer_command_buffer: ^Command_Buffer,
  instance_index:          u32,
  transform_index:         u32,
  default_material:        u32,
  arena:                   ^mem.Arena,
  allocator:               runtime.Allocator,
  tmp_arena:               ^mem.Arena,
  tmp_allocator:           runtime.Allocator,
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

  ctx.transfer_queue = queue_get(ctx, .Transfer, 1) or_return

  ctx.transfer_command_pool = command_pool_create(
    ctx,
    ctx.transfer_queue,
    2,
  ) or_return

  ctx.transfer_command_buffer = command_buffer_allocate(
    ctx,
    ctx.transfer_command_pool,
  ) or_return

  ctx.draw_queue = queue_get(ctx, .Graphics, 1) or_return

  ctx.draw_command_pool = command_pool_create(ctx, ctx.draw_queue, 2) or_return

  ctx.draw_command_buffer = command_buffer_allocate(
    ctx,
    ctx.draw_command_pool,
  ) or_return

  ctx.draw_fence = fence_create(ctx) or_return
  ctx.copy_fence = fence_create(ctx) or_return
  ctx.semaphore = semaphore_create(ctx) or_return

  command_buffer_begin(ctx, ctx.transfer_command_buffer) or_return

  ctx.set_layouts = vector.new(
    Descriptor_Set_Layout,
    20,
    ctx.allocator,
  ) or_return

  ctx.pipeline_layouts = vector.new(
    Pipeline_Layout,
    20,
    ctx.allocator,
  ) or_return

  ctx.render_passes = vector.new(Render_Pass, 20, ctx.allocator) or_return
  ctx.geometries = vector.new(Geometry, 20, ctx.allocator) or_return
  ctx.materials = vector.new(Material, 20, ctx.allocator) or_return
  ctx.shaders = vector.new(Shader_Module, 20, ctx.allocator) or_return
  ctx.images = vector.new(Image, 10, ctx.allocator) or_return
  ctx.buffers = vector.new(Buffer, 20, ctx.allocator) or_return

  ctx.descriptor_pools = vector.new(
    Descriptor_Pool,
    10,
    ctx.allocator,
  ) or_return

  MAX_INSTANCES :: 50

  ctx.staging = vector.one(&ctx.buffers) or_return
  buffer_create(
    ctx.staging,
    ctx,
    size_of(Matrix) * 256 * 1000,
    {.TRANSFER_SRC},
    {.HOST_COHERENT, .HOST_VISIBLE},
  ) or_return

  ctx.projection = vector.one(&ctx.buffers) or_return
  buffer_create(
    ctx.projection,
    ctx,
    size_of(Matrix) * 2,
    {.UNIFORM_BUFFER, .TRANSFER_DST},
    {.DEVICE_LOCAL},
  ) or_return

  ctx.light = vector.one(&ctx.buffers) or_return
  buffer_create(
    ctx.light,
    ctx,
    size_of(Light) * 1,
    {.STORAGE_BUFFER, .TRANSFER_DST},
    {.DEVICE_LOCAL},
  ) or_return

  ctx.material_buffer = vector.one(&ctx.buffers) or_return
  buffer_create(
    ctx.material_buffer,
    ctx,
    size_of(Material) * MAX_INSTANCES,
    {.STORAGE_BUFFER, .TRANSFER_DST},
    {.DEVICE_LOCAL},
  ) or_return

  ctx.model_buffer = vector.one(&ctx.buffers) or_return
  buffer_create(
    ctx.model_buffer,
    ctx,
    size_of(Instance_Model) * MAX_INSTANCES,
    {.STORAGE_BUFFER, .TRANSFER_DST},
    {.DEVICE_LOCAL},
  ) or_return

  ctx.transform_buffer = vector.one(&ctx.buffers) or_return
  buffer_create(
    ctx.transform_buffer,
    ctx,
    size_of(Matrix) * MAX_INSTANCES,
    {.STORAGE_BUFFER, .TRANSFER_DST},
    {.DEVICE_LOCAL},
  ) or_return

  ctx.transform_offset_buffer = vector.one(&ctx.buffers) or_return
  buffer_create(
    ctx.transform_offset_buffer,
    ctx,
    size_of(u32) * MAX_INSTANCES,
    {.STORAGE_BUFFER, .TRANSFER_DST},
    {.DEVICE_LOCAL},
  ) or_return

  ctx.material_offset_buffer = vector.one(&ctx.buffers) or_return
  buffer_create(
    ctx.material_offset_buffer,
    ctx,
    size_of(u32) * MAX_INSTANCES,
    {.STORAGE_BUFFER, .TRANSFER_DST},
    {.DEVICE_LOCAL},
  ) or_return

  ctx.render_pass = vector.one(&ctx.render_passes) or_return
  ctx.render_pass.pipelines = vector.new(Pipeline, 10, ctx.allocator) or_return
  ctx.render_pass.unused = vector.new(Pipeline, 10, ctx.allocator) or_return

  render_pass_create(ctx.render_pass, ctx) or_return

  ctx.descriptor_pool = vector.one(&ctx.descriptor_pools) or_return
  descriptor_pool_create(
    ctx.descriptor_pool,
    ctx,
    {
      {type = .UNIFORM_BUFFER, descriptorCount = 20},
      {type = .STORAGE_BUFFER, descriptorCount = 20},
    },
    20,
  ) or_return

  ctx.writes = vector.new(
    vk.WriteDescriptorSet,
    20 * 2,
    ctx.allocator,
  ) or_return

  ctx.infos = vector.new(
    vk.DescriptorBufferInfo,
    20 * 2,
    ctx.allocator,
  ) or_return

  fixed_set_layout := set_layout_create(
    ctx,
    {
      vk.DescriptorSetLayoutBinding {
        descriptorType = .UNIFORM_BUFFER,
        stageFlags = {.VERTEX},
        descriptorCount = 1,
        binding = 0,
      },
      vk.DescriptorSetLayoutBinding {
        descriptorType = .STORAGE_BUFFER,
        stageFlags = {.VERTEX},
        descriptorCount = 1,
        binding = 1,
      },
    },
  ) or_return

  ctx.fixed_set = descriptor_set_allocate(
    ctx,
    ctx.descriptor_pool,
    fixed_set_layout,
  ) or_return

  dynamic_set_layout := set_layout_create(
    ctx,
    {
      vk.DescriptorSetLayoutBinding {
        descriptorType = .STORAGE_BUFFER,
        stageFlags = {.VERTEX},
        descriptorCount = 1,
        binding = 0,
      },
      vk.DescriptorSetLayoutBinding {
        descriptorType = .STORAGE_BUFFER,
        stageFlags = {.VERTEX},
        descriptorCount = 1,
        binding = 1,
      },
      vk.DescriptorSetLayoutBinding {
        descriptorType = .STORAGE_BUFFER,
        stageFlags = {.VERTEX},
        descriptorCount = 1,
        binding = 2,
      },
      vk.DescriptorSetLayoutBinding {
        descriptorType = .STORAGE_BUFFER,
        stageFlags = {.VERTEX},
        descriptorCount = 1,
        binding = 3,
      },
      vk.DescriptorSetLayoutBinding {
        descriptorType = .STORAGE_BUFFER,
        stageFlags = {.VERTEX},
        descriptorCount = 1,
        binding = 4,
      },
    },
    // binding_create(
    //   1,
    //   {.FRAGMENT},
    //   .COMBINED_IMAGE_SAMPLER,
    //   {.STORAGE_BUFFER, .TRANSFER_DST},
    //   {.DEVICE_LOCAL},
    //   size_of(u32),
    // ),
  ) or_return

  ctx.dynamic_set = descriptor_set_allocate(
    ctx,
    ctx.descriptor_pool,
    dynamic_set_layout,
  ) or_return

  layout := vector.one(&ctx.pipeline_layouts) or_return
  pipeline_layout_create(
    layout,
    ctx,
    {fixed_set_layout, dynamic_set_layout},
  ) or_return

  unboned_shader := vector.one(&ctx.shaders) or_return
  shader_module_create(
    unboned_shader,
    ctx,
    "assets/output/unboned.spv",
  ) or_return

  boned_shader := vector.one(&ctx.shaders) or_return
  shader_module_create(boned_shader, ctx, "assets/output/boned.spv") or_return

  plain_shader := vector.one(&ctx.shaders) or_return
  shader_module_create(plain_shader, ctx, "assets/output/plain.spv") or_return

  fragment_shader := vector.one(&ctx.shaders) or_return
  shader_module_create(
    fragment_shader,
    ctx,
    "assets/output/frag.spv",
  ) or_return

  defer {
    shader_module_destroy(ctx, unboned_shader)
    shader_module_destroy(ctx, boned_shader)
    shader_module_destroy(ctx, plain_shader)
    shader_module_destroy(ctx, fragment_shader)
  }

  ctx.default_pipeline = vector.one(&ctx.render_pass.pipelines) or_return
  pipeline_create(
    ctx.default_pipeline,
    ctx,
    ctx.render_pass,
    layout,
    unboned_shader,
    fragment_shader,
    {{{.Sfloat, 3}, {.Sfloat, 3}, {.Sfloat, 2}}},
  ) or_return

  ctx.plain_pipeline = vector.one(&ctx.render_pass.pipelines) or_return
  pipeline_create(
    ctx.plain_pipeline,
    ctx,
    ctx.render_pass,
    layout,
    plain_shader,
    fragment_shader,
    {{{.Sfloat, 3}, {.Sfloat, 3}, {.Sfloat, 2}}},
  ) or_return

  ctx.boned_pipeline = vector.one(&ctx.render_pass.pipelines) or_return
  pipeline_create(
    ctx.boned_pipeline,
    ctx,
    ctx.render_pass,
    layout,
    boned_shader,
    fragment_shader,
    {{{.Sfloat, 3}, {.Sfloat, 3}, {.Sfloat, 2}, {.Sfloat, 4}, {.Uint, 4}}},
  ) or_return

  ctx.frames = frames_create(
    ctx,
    ctx.render_pass,
    frame_count,
    width,
    height,
  ) or_return

  ctx.default_material = material_create(
    ctx,
    Material{0, 0.8, 0.2, 1},
  ) or_return

  img := image_from_file(ctx, "assets/burger.png") or_return

  return nil
}

vulkan_deinit :: proc(ctx: ^Vulkan_Context) {
  vk.WaitForFences(ctx.device.handle, 1, &ctx.draw_fence, true, 0xFFFFFF)
  vk.WaitForFences(ctx.device.handle, 1, &ctx.copy_fence, true, 0xFFFFFF)

  vk.DestroySemaphore(ctx.device.handle, ctx.semaphore, nil)
  vk.DestroyFence(ctx.device.handle, ctx.draw_fence, nil)
  vk.DestroyFence(ctx.device.handle, ctx.copy_fence, nil)

  for i in 0 ..< ctx.images.len {
    image_destroy(ctx, &ctx.images.data[i])
  }

  for i in 0 ..< ctx.frames.len {
    frame_destroy(ctx, &ctx.frames.data[i])
  }

  for i in 0 ..< ctx.pipeline_layouts.len {
    vk.DestroyPipelineLayout(
      ctx.device.handle,
      ctx.pipeline_layouts.data[i].handle,
      nil,
    )
  }

  for i in 0 ..< ctx.set_layouts.len {
    vk.DestroyDescriptorSetLayout(
      ctx.device.handle,
      ctx.set_layouts.data[i].handle,
      nil,
    )
  }

  for i in 0 ..< ctx.buffers.len {
    buffer_destroy(ctx, &ctx.buffers.data[i])
  }

  for i in 0 ..< ctx.descriptor_pools.len {
    descriptor_pool_deinit(ctx, &ctx.descriptor_pools.data[i])
  }

  for i in 0 ..< ctx.render_passes.len {
    render_pass_deinit(ctx, &ctx.render_passes.data[i])
  }

  device_deinit(&ctx.device)

  vk.DestroyInstance(ctx.instance, nil)

  _ = dynlib.unload_library(library)
}

@(private)
load_fn :: proc(ptr: rawptr, name: cstring) {
  (cast(^rawptr)ptr)^ = dynlib.symbol_address(library, string(name))
}
