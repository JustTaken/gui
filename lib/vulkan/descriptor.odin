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
  parent:      ^Descriptor_Pool,
  handle:      vk.DescriptorSet,
  descriptors: vector.Vector(Descriptor),
}

@(private)
Descriptor_Pool :: struct {
  handle: vk.DescriptorPool,
  sets:   vector.Vector(Descriptor_Set),
  writes: vector.Vector(vk.WriteDescriptorSet),
  infos:  vector.Vector(vk.DescriptorBufferInfo),
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
  set.parent = pool

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

  raw_bindings := vector.new(
    vk.DescriptorSetLayoutBinding,
    u32(len(bindings)),
    ctx.tmp_allocator,
  ) or_return

  set_layout.bindings = vector.new(
    Descriptor_Set_Layout_Binding,
    u32(len(bindings)),
    ctx.allocator,
  ) or_return

  for i in 0 ..< len(bindings) {
    binding := vector.one(&set_layout.bindings) or_return

    binding^ = bindings[i]
    binding.handle.binding = u32(i)

    vector.append(&raw_bindings, binding.handle) or_return
  }

  set_layout_info := vk.DescriptorSetLayoutCreateInfo {
    sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
    bindingCount = raw_bindings.len,
    pBindings    = &raw_bindings.data[0],
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

  pool.writes = vector.new(
    vk.WriteDescriptorSet,
    max * 2,
    ctx.allocator,
  ) or_return

  pool.infos = vector.new(
    vk.DescriptorBufferInfo,
    max * 2,
    ctx.allocator,
  ) or_return

  return pool, nil
}

@(private)
descriptor_set_update :: proc(
  $T: typeid,
  ctx: ^Vulkan_Context,
  set: ^Descriptor_Set,
  descriptor_index: u32,
  data: []T,
  offset: u32,
) -> error.Error {
  copy_data_to_buffer(
    T,
    ctx,
    data,
    &set.descriptors.data[descriptor_index].buffer,
    offset,
  ) or_return

  write := vector.one(&set.parent.writes) or_return
  info := vector.one(&set.parent.infos) or_return

  descriptor := &set.descriptors.data[descriptor_index]

  info.buffer = descriptor.buffer.handle
  info.offset = vk.DeviceSize(offset * size_of(T))
  info.range = vk.DeviceSize(size_of(T) * len(data))

  write.sType = .WRITE_DESCRIPTOR_SET
  write.dstSet = set.handle
  write.descriptorType = descriptor.kind
  write.dstBinding = descriptor.binding
  write.pBufferInfo = info
  write.descriptorCount = 1
  write.dstArrayElement = 0
  write.pNext = nil
  write.pImageInfo = nil
  write.pTexelBufferView = nil

  return nil
}

@(private)
descriptor_pool_update :: proc(
  ctx: ^Vulkan_Context,
  descriptor_pool: ^Descriptor_Pool,
) {
  defer {
    descriptor_pool.writes.len = 0
    descriptor_pool.infos.len = 0
  }

  if descriptor_pool.writes.len == 0 do return
  log.info("Writing updates to descriptors:", descriptor_pool.writes.len)

  vk.UpdateDescriptorSets(
    ctx.device.handle,
    descriptor_pool.writes.len,
    &descriptor_pool.writes.data[0],
    0,
    nil,
  )
}

update_projection :: proc(
  ctx: ^Vulkan_Context,
  projection: Matrix,
) -> error.Error {
  m := [?]Matrix{projection}
  descriptor_set_update(
    Matrix,
    ctx,
    ctx.fixed_set,
    TRANSFORMS,
    m[:],
    0,
  ) or_return

  return nil
}

update_view :: proc(ctx: ^Vulkan_Context, view: Matrix) -> error.Error {
  m := [?]Matrix{view}
  descriptor_set_update(
    Matrix,
    ctx,
    ctx.fixed_set,
    TRANSFORMS,
    m[:],
    1,
  ) or_return

  return nil
}

update_light :: proc(ctx: ^Vulkan_Context, light: Light) -> error.Error {
  m := [?]Light{light}
  descriptor_set_update(Light, ctx, ctx.fixed_set, LIGHTS, m[:], 0) or_return

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
