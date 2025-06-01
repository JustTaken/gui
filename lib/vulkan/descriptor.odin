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
  bindings: vector.Vector(vk.DescriptorSetLayoutBinding),
}

@(private)
Descriptor_Set :: struct {
  handle: vk.DescriptorSet,
  layout: ^Descriptor_Set_Layout,
  // to_update:   vector.Vector(bool),
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
) -> (
  set: ^Descriptor_Set,
  err: error.Error,
) {
  set = vector.one(&pool.sets) or_return
  set.layout = layout

  layouts := [?]vk.DescriptorSetLayout{set.layout.handle}
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

  // set.descriptors = vector.new(
  //   Descriptor,
  //   layout.bindings.len,
  //   ctx.allocator,
  // ) or_return

  // set.to_update = vector.new(
  //   bool,
  //   layout.bindings.len,
  //   ctx.allocator,
  // ) or_return

  // for i in 0 ..< layout.bindings.len {
  //   vector.append(&set.to_update, false) or_return

  //   descriptor := vector.one(&set.descriptors) or_return

  //   descriptor.kind = layout.bindings.data[i].kind
  //   descriptor.size = counts[i] * layout.bindings.data[i].type_size
  //   descriptor.binding = u32(i)
  // }

  return set, nil
}


// @(private)
// binding_create :: proc(
//   count: u32,
//   flags: vk.ShaderStageFlags,
//   kind: vk.DescriptorType,
//   size: u32,
// ) -> Descriptor_Set_Layout_Binding {
//   return Descriptor_Set_Layout_Binding {
//     type_size = size,
//     kind = kind,
//     usage = usage,
//     properties = properties,
//     handle = vk.DescriptorSetLayoutBinding {
//       descriptorType = kind,
//       descriptorCount = count,
//       stageFlags = flags,
//     },
//   }
// }

@(private)
set_layout_create :: proc(
  ctx: ^Vulkan_Context,
  bindings: []vk.DescriptorSetLayoutBinding,
) -> (
  set_layout: ^Descriptor_Set_Layout,
  err: error.Error,
) {
  set_layout = vector.one(&ctx.set_layouts) or_return

  set_layout.bindings = vector.new(
    vk.DescriptorSetLayoutBinding,
    u32(len(bindings)),
    ctx.allocator,
  ) or_return

  for i in 0 ..< len(bindings) {
    vector.append(&set_layout.bindings, bindings[i]) or_return
  }

  set_layout_info := vk.DescriptorSetLayoutCreateInfo {
    sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
    bindingCount = set_layout.bindings.len,
    pBindings    = &set_layout.bindings.data[0],
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
  pool: ^Descriptor_Pool,
  ctx: ^Vulkan_Context,
  sizes: []vk.DescriptorPoolSize,
  max: u32,
) -> error.Error {
  info := vk.DescriptorPoolCreateInfo {
    sType         = .DESCRIPTOR_POOL_CREATE_INFO,
    poolSizeCount = u32(len(sizes)),
    pPoolSizes    = &sizes[0],
    maxSets       = max,
  }

  pool.sets = vector.new(Descriptor_Set, max, ctx.allocator) or_return

  if vk.CreateDescriptorPool(ctx.device.handle, &info, nil, &pool.handle) !=
     nil {
    return .CreateDescriptorPoolFailed
  }

  return nil
}

@(private)
descriptor_set_update :: proc(
  $T: typeid,
  ctx: ^Vulkan_Context,
  set: ^Descriptor_Set,
  buffer: ^Buffer,
  binding: u32,
  offset: u32 = 0,
) -> error.Error {
  write := vector.one(&ctx.writes) or_return
  info := vector.one(&ctx.infos) or_return

  info.buffer = buffer.handle
  info.offset = vk.DeviceSize(offset)
  info.range = vk.DeviceSize(buffer.cap)

  write.sType = .WRITE_DESCRIPTOR_SET
  write.dstSet = set.handle
  write.descriptorType = set.layout.bindings.data[binding].descriptorType
  write.dstBinding = binding
  write.pBufferInfo = info
  write.descriptorCount = 1
  write.dstArrayElement = 0
  write.pNext = nil
  write.pImageInfo = nil
  write.pTexelBufferView = nil

  return nil
}

@(private)
descriptors_update :: proc(ctx: ^Vulkan_Context) {
  defer {
    ctx.writes.len = 0
    ctx.infos.len = 0
  }

  if ctx.writes.len == 0 do return

  vk.UpdateDescriptorSets(
    ctx.device.handle,
    ctx.writes.len,
    &ctx.writes.data[0],
    0,
    nil,
  )
}

update_projection :: proc(
  ctx: ^Vulkan_Context,
  projection: Matrix,
) -> error.Error {
  m := [?]Matrix{projection}
  copy_data_to_buffer(Matrix, ctx, m[:], ctx.projection, 0) or_return
  descriptor_set_update(
    Matrix,
    ctx,
    ctx.fixed_set,
    ctx.projection,
    TRANSFORMS,
  ) or_return

  return nil
}

update_view :: proc(ctx: ^Vulkan_Context, view: Matrix) -> error.Error {
  m := [?]Matrix{view}

  copy_data_to_buffer(Matrix, ctx, m[:], ctx.projection, 1) or_return
  descriptor_set_update(
    Matrix,
    ctx,
    ctx.fixed_set,
    ctx.projection,
    TRANSFORMS,
  ) or_return

  return nil
}

update_light :: proc(ctx: ^Vulkan_Context, light: Light) -> error.Error {
  m := [?]Light{light}
  copy_data_to_buffer(Light, ctx, m[:], ctx.light, 0) or_return

  descriptor_set_update(Light, ctx, ctx.fixed_set, ctx.light, LIGHTS) or_return

  return nil
}

@(private)
descriptor_pool_deinit :: proc(ctx: ^Vulkan_Context, pool: ^Descriptor_Pool) {
  vk.DestroyDescriptorPool(ctx.device.handle, pool.handle, nil)
}
