package vulk

import "core:log"
import vk "vendor:vulkan"

import "lib:collection/vector"
import "lib:error"

TRANSFORMS :: 0
LIGHTS :: 1

MATERIALS :: 0
MODELS :: 1
DYNAMIC_TRANSFORMS :: 2
TRANSFORM_OFFSETS :: 3
MATERIAL_OFFSETS :: 4

@(private)
Descriptor_Set_Layout_Binding :: struct {
  handle:     vk.DescriptorSetLayoutBinding,
  kind:       vk.DescriptorType,
  usage:      vk.BufferUsageFlags,
  properties: vk.MemoryPropertyFlags,
  type_size:  u32,
}

@(private)
Descriptor_Set_Layout :: struct {
  handle:   vk.DescriptorSetLayout,
  bindings: vector.Vector(Descriptor_Set_Layout_Binding),
}

@(private)
Descriptor_Info :: struct {
  count: u32,
}

@(private)
Descriptor :: struct {
  buffer:  Buffer,
  kind:    vk.DescriptorType,
  size:    u32,
  binding: u32,
}

@(private)
Descriptor_Set :: struct {
  handle:      vk.DescriptorSet,
  descriptors: vector.Vector(Descriptor),
}

@(private)
Descriptor_Pool :: struct {
  handle: vk.DescriptorPool,
  sets:   vector.Vector(Descriptor_Set),
}

@(private)
descriptor_set_allocate :: proc(
  ctx: ^Vulkan_Context,
  pool: ^Descriptor_Pool,
  layout: ^Descriptor_Set_Layout,
  counts: []u32,
) -> (
  set: ^Descriptor_Set,
  err: error.Error,
) {
  set = vector.one(&pool.sets) or_return

  layouts := [?]vk.DescriptorSetLayout{layout.handle}
  info := vk.DescriptorSetAllocateInfo {
    sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
    descriptorPool     = pool.handle,
    descriptorSetCount = u32(len(layouts)),
    pSetLayouts        = &layouts[0],
  }

  if vk.AllocateDescriptorSets(ctx.device.handle, &info, &set.handle) !=
     .SUCCESS {
    return set, .AllocateDescriptorSetFailed
  }

  set.descriptors = vector.new(
    Descriptor,
    layout.bindings.len,
    ctx.allocator,
  ) or_return

  for i in 0 ..< layout.bindings.len {
    descriptor := vector.one(&set.descriptors) or_return
    descriptor.kind = layout.bindings.data[i].kind
    descriptor.size = counts[i] * layout.bindings.data[i].type_size
    descriptor.binding = u32(i)
    descriptor.buffer = buffer_create(
      ctx,
      descriptor.size,
      layout.bindings.data[i].usage,
      layout.bindings.data[i].properties,
    ) or_return
  }

  return set, nil
}


@(private)
binding_create :: proc(
  typ: vk.DescriptorType,
  count: u32,
  flags: vk.ShaderStageFlags,
  kind: vk.DescriptorType,
  usage: vk.BufferUsageFlags,
  properties: vk.MemoryPropertyFlags,
  size: u32,
) -> Descriptor_Set_Layout_Binding {
  return Descriptor_Set_Layout_Binding {
    type_size = size,
    kind = kind,
    usage = usage,
    properties = properties,
    handle = vk.DescriptorSetLayoutBinding {
      descriptorType = typ,
      descriptorCount = count,
      stageFlags = flags,
    },
  }
}

@(private)
set_layout_create :: proc(
  ctx: ^Vulkan_Context,
  bindings: []Descriptor_Set_Layout_Binding,
) -> (
  set_layout: ^Descriptor_Set_Layout,
  err: error.Error,
) {
  set_layout = vector.one(&ctx.set_layouts) or_return

  raw_bindings := make(
    []vk.DescriptorSetLayoutBinding,
    len(bindings),
    ctx.tmp_allocator,
  )

  set_layout.bindings = vector.new(
    Descriptor_Set_Layout_Binding,
    u32(len(bindings)),
    ctx.allocator,
  ) or_return

  for i in 0 ..< len(bindings) {
    binding := vector.one(&set_layout.bindings) or_return

    binding^ = bindings[i]
    binding.handle.binding = u32(i)

    raw_bindings[i] = binding.handle
  }

  set_layout_info := vk.DescriptorSetLayoutCreateInfo {
    sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
    bindingCount = u32(len(raw_bindings)),
    pBindings    = &raw_bindings[0],
  }

  if vk.CreateDescriptorSetLayout(
       ctx.device.handle,
       &set_layout_info,
       nil,
       &set_layout.handle,
     ) !=
     .SUCCESS {
    return set_layout, .CreateDescriptorSetLayoutFailed
  }

  return set_layout, nil
}

@(private)
descriptor_pool_create :: proc(
  ctx: ^Vulkan_Context,
  sizes: []vk.DescriptorPoolSize,
  max: u32,
) -> (
  pool: Descriptor_Pool,
  err: error.Error,
) {
  info := vk.DescriptorPoolCreateInfo {
    sType         = .DESCRIPTOR_POOL_CREATE_INFO,
    poolSizeCount = u32(len(sizes)),
    pPoolSizes    = &sizes[0],
    maxSets       = max,
  }

  pool.sets = vector.new(Descriptor_Set, max, ctx.allocator) or_return
  if vk.CreateDescriptorPool(ctx.device.handle, &info, nil, &pool.handle) !=
     nil {
    return pool, .CreateDescriptorPoolFailed
  }

  return pool, nil
}

@(private)
descriptor_set_update :: proc(ctx: ^Vulkan_Context, set: Descriptor_Set) {
  writes := make(
    []vk.WriteDescriptorSet,
    set.descriptors.len,
    ctx.tmp_allocator,
  )

  infos := make(
    []vk.DescriptorBufferInfo,
    set.descriptors.len,
    ctx.tmp_allocator,
  )

  count := 0
  for i in 0 ..< set.descriptors.len {
    descriptor := &set.descriptors.data[i]

    if descriptor.size == 0 do continue

    infos[count].offset = 0
    infos[count].buffer = descriptor.buffer.handle
    infos[count].range = vk.DeviceSize(descriptor.size)

    writes[count].sType = .WRITE_DESCRIPTOR_SET
    writes[count].dstSet = set.handle
    writes[count].dstBinding = descriptor.binding
    writes[count].dstArrayElement = 0
    writes[count].descriptorCount = 1
    writes[count].pBufferInfo = &infos[count]
    writes[count].descriptorType = descriptor.kind

    count += 1
  }

  vk.UpdateDescriptorSets(ctx.device.handle, u32(count), &writes[0], 0, nil)
}

update_projection :: proc(
  ctx: ^Vulkan_Context,
  projection: Matrix,
) -> error.Error {
  m := [?]Matrix{projection}
  copy_data(
    Matrix,
    ctx,
    m[:],
    &ctx.fixed_set.descriptors.data[TRANSFORMS].buffer,
    0,
  ) or_return

  return nil
}

update_view :: proc(ctx: ^Vulkan_Context, view: Matrix) -> error.Error {
  m := [?]Matrix{view}
  copy_data(
    Matrix,
    ctx,
    m[:],
    &ctx.fixed_set.descriptors.data[TRANSFORMS].buffer,
    1,
  ) or_return

  return nil
}

update_light :: proc(ctx: ^Vulkan_Context, light: Light) -> error.Error {
  m := [?]Light{light}
  copy_data(
    Light,
    ctx,
    m[:],
    &ctx.fixed_set.descriptors.data[LIGHTS].buffer,
    0,
  ) or_return

  return nil
}

@(private)
submit_staging_data :: proc(ctx: ^Vulkan_Context) -> error.Error {
  if !ctx.staging.recording do return nil

  if vk.EndCommandBuffer(ctx.command_buffers.data[1]) != .SUCCESS do return .EndCommandBufferFailed

  submit_info := vk.SubmitInfo {
    sType              = .SUBMIT_INFO,
    commandBufferCount = 1,
    pCommandBuffers    = &ctx.command_buffers.data[1],
  }

  vk.ResetFences(ctx.device.handle, 1, &ctx.copy_fence)
  if vk.QueueSubmit(ctx.device.queues[1].handle, 1, &submit_info, ctx.copy_fence) != .SUCCESS do return .QueueSubmitFailed
  if vk.WaitForFences(ctx.device.handle, 1, &ctx.copy_fence, true, 0xFFFFFF) != .SUCCESS do return .WaitFencesFailed

  ctx.staging.recording = false
  ctx.staging.buffer.len = 0

  for i in 0 ..< ctx.descriptor_pool.sets.len {
    descriptor_set_update(ctx, ctx.descriptor_pool.sets.data[i])
  }

  return nil
}

@(private)
descriptor_set_deinit :: proc(ctx: ^Vulkan_Context, set: Descriptor_Set) {
  for i in 0 ..< set.descriptors.len {
    buffer_destroy(ctx, set.descriptors.data[i].buffer)
  }
}

@(private)
descriptor_pool_deinit :: proc(ctx: ^Vulkan_Context, pool: Descriptor_Pool) {
  for i in 0 ..< pool.sets.len {
    descriptor_set_deinit(ctx, pool.sets.data[i])
  }

  vk.DestroyDescriptorPool(ctx.device.handle, pool.handle, nil)
}
