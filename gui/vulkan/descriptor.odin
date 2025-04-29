package vulk

import vk "vendor:vulkan"

Descriptor_Set_Layout :: struct {
  handle: vk.DescriptorSetLayout,
  bindings: []vk.DescriptorSetLayoutBinding,
  type_sizes: []u32,
}

Descriptor :: struct {
  buffer: Buffer,
  kind:    vk.DescriptorType,
  size:    vk.DeviceSize,
  binding: u32,
}

Descriptor_Set :: struct {
  handle:      vk.DescriptorSet,
  layout:      Descriptor_Set_Layout,
  descriptors: []Descriptor,
}

descriptor_create :: proc(ctx: ^Vulkan_Context, kind: vk.DescriptorType, size: vk.DeviceSize, binding: u32, usage: vk.BufferUsageFlags, properties: vk.MemoryPropertyFlags) -> (descriptor: Descriptor, err: Error) {
  descriptor.kind = kind
  descriptor.size = size
  descriptor.binding = binding

  descriptor.buffer = buffer_create(ctx, size, usage, properties) or_return

  return descriptor, nil
}

descriptor_set_create :: proc(ctx: ^Vulkan_Context, layout: Descriptor_Set_Layout, usages: []vk.BufferUsageFlags, properties: []vk.MemoryPropertyFlags, counts: []u32) -> Error {
  binding_count := len(layout.bindings)

  assert(binding_count == len(layout.type_sizes))
  assert(binding_count == len(usages))
  assert(binding_count == len(properties))
  assert(binding_count == len(counts))

  descriptors := make([]Descriptor, binding_count, ctx.allocator)

  descriptor_handle := allocate_descriptor_set(ctx, ctx.set_layout.handle, ctx.descriptor_pool) or_return

  for i in 0..<binding_count {
    descriptors[i] = descriptor_create(ctx, layout.bindings[i].descriptorType, vk.DeviceSize(layout.type_sizes[i] * counts[i]), u32(layout.bindings[i].binding), usages[i], properties[i]) or_return
  }

  ctx.descriptor_set = Descriptor_Set{handle = descriptor_handle, layout = ctx.set_layout, descriptors = descriptors}

  return nil
}

create_set_layout :: proc(ctx: ^Vulkan_Context, device: vk.Device) -> (set_layout: Descriptor_Set_Layout, err: Error) {
  count :: 4

  set_layout.type_sizes = make([]u32, count, ctx.allocator)
  set_layout.bindings = make([]vk.DescriptorSetLayoutBinding, count, ctx.allocator)

  set_layout.type_sizes[0] = size_of(Matrix)
  set_layout.bindings[0] = {
    binding = 0,
    stageFlags = {.VERTEX},
    descriptorType = .UNIFORM_BUFFER,
    descriptorCount = 1,
  }
  set_layout.type_sizes[1] = size_of(InstanceModel)
  set_layout.bindings[1] = {
    binding = 1,
    stageFlags = {.VERTEX},
    descriptorType = .STORAGE_BUFFER,
    descriptorCount = 1,
  }

  set_layout.type_sizes[2] = size_of(Color)
  set_layout.bindings[2] = {
    binding = 2,
    stageFlags = {.VERTEX},
    descriptorType = .STORAGE_BUFFER,
    descriptorCount = 1,
  }

  set_layout.type_sizes[3] = size_of(Light)
  set_layout.bindings[3] = {
    binding = 3,
    stageFlags = {.VERTEX},
    descriptorType = .STORAGE_BUFFER,
    descriptorCount = 1,
  }

  set_layout_info := vk.DescriptorSetLayoutCreateInfo {
      sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
      bindingCount = u32(len(set_layout.bindings)),
      pBindings = &set_layout.bindings[0],
  }

  if vk.CreateDescriptorSetLayout(device, &set_layout_info, nil, &set_layout.handle) != .SUCCESS {
    return set_layout, .CreateDescriptorSetLayoutFailed
  }

  return set_layout, nil
}

create_layout :: proc(device: vk.Device, set_layout: vk.DescriptorSetLayout) -> (vk.PipelineLayout, Error) {
  set_layouts := [?]vk.DescriptorSetLayout{ set_layout }
  layout_info := vk.PipelineLayoutCreateInfo {
    sType    = .PIPELINE_LAYOUT_CREATE_INFO,
    setLayoutCount = u32(len(set_layouts)),
    pSetLayouts    = &set_layouts[0],
  }

  layout: vk.PipelineLayout
  if vk.CreatePipelineLayout(device, &layout_info, nil, &layout) != .SUCCESS {
    return layout, .CreatePipelineLayouFailed
  }

  return layout, nil
}

create_descriptor_pool :: proc(device: vk.Device) -> (vk.DescriptorPool, Error) {
  sizes := [?]vk.DescriptorPoolSize {
    {type = .UNIFORM_BUFFER, descriptorCount = 10},
    {type = .STORAGE_BUFFER, descriptorCount = 10},
  }

  info := vk.DescriptorPoolCreateInfo {
    sType   = .DESCRIPTOR_POOL_CREATE_INFO,
    poolSizeCount = u32(len(sizes)),
    pPoolSizes    = &sizes[0],
    maxSets       = 2,
  }

  pool: vk.DescriptorPool
  if vk.CreateDescriptorPool(device, &info, nil, &pool) != nil do return pool, .CreateDescriptorPoolFailed

  return pool, nil
}

allocate_descriptor_set :: proc(ctx: ^Vulkan_Context, layout: vk.DescriptorSetLayout, pool: vk.DescriptorPool) -> (set: vk.DescriptorSet, err: Error) {
  layouts := [?]vk.DescriptorSetLayout { layout }
  info := vk.DescriptorSetAllocateInfo {
    sType        = .DESCRIPTOR_SET_ALLOCATE_INFO,
    descriptorPool     = pool,
    descriptorSetCount = u32(len(layouts)),
    pSetLayouts  = &layouts[0],
  }

  if vk.AllocateDescriptorSets(ctx.device, &info, &set) != .SUCCESS {
    return set, .AllocateDescriptorSetFailed
  }

  return set, nil
}

update_descriptor_set :: proc(ctx: ^Vulkan_Context, set: Descriptor_Set) -> Error {
  total := u32(len(set.descriptors))

  writes := make([]vk.WriteDescriptorSet, total, ctx.tmp_allocator)
  infos := make([]vk.DescriptorBufferInfo, total, ctx.tmp_allocator)

  count := 0
  for i in 0 ..< total {
    descriptor := &set.descriptors[i]
    if descriptor.size == 0 do continue

    infos[count].offset = 0
    infos[count].buffer = descriptor.buffer.handle
    infos[count].range = descriptor.size

    writes[count].sType = .WRITE_DESCRIPTOR_SET
    writes[count].dstSet = set.handle
    writes[count].dstBinding = descriptor.binding
    writes[count].dstArrayElement = 0
    writes[count].descriptorCount = 1
    writes[count].pBufferInfo = &infos[count]
    writes[count].descriptorType = descriptor.kind

    count += 1
  }

  vk.UpdateDescriptorSets(ctx.device, u32(count), &writes[0], 0, nil)

  return nil
}

update_projection :: proc(ctx: ^Vulkan_Context, projection: Matrix) -> Error {
  m := [?]Matrix{projection}
  vulkan_copy_data(Matrix, ctx, m[:], ctx.descriptor_set.descriptors[TRANSFORMS].buffer.handle, 0) or_return

  return nil
}

update_view :: proc(ctx: ^Vulkan_Context, view: Matrix) -> Error {
  m := [?]Matrix{view}
  vulkan_copy_data(Matrix, ctx, m[:], ctx.descriptor_set.descriptors[TRANSFORMS].buffer.handle, size_of(Matrix)) or_return

  return nil
}

update_light :: proc(ctx: ^Vulkan_Context, light: Light) -> Error {
  m := [?]Light{light}
  vulkan_copy_data(Light, ctx, m[:], ctx.descriptor_set.descriptors[LIGHTS].buffer.handle, 0) or_return

  return nil
}

submit_staging_data :: proc(ctx: ^Vulkan_Context) -> Error {
  if !ctx.staging.recording do return nil

  if vk.EndCommandBuffer(ctx.command_buffers[1]) != .SUCCESS do return .EndCommandBufferFailed

  submit_info := vk.SubmitInfo {
    sType        = .SUBMIT_INFO,
    commandBufferCount = 1,
    pCommandBuffers    = &ctx.command_buffers[1],
  }

  vk.ResetFences(ctx.device, 1, &ctx.copy_fence)
  if vk.QueueSubmit(ctx.queues[1], 1, &submit_info, ctx.copy_fence) != .SUCCESS do return .QueueSubmitFailed
  if vk.WaitForFences(ctx.device, 1, &ctx.copy_fence, true, 0xFFFFFF) != .SUCCESS do return .WaitFencesFailed

  ctx.staging.recording = false
  ctx.staging.buffer.len = 0

  update_descriptor_set(ctx, ctx.descriptor_set) or_return

  return nil
}
