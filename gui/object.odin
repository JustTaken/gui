package main

import vk "vendor:vulkan"

InstanceModel :: matrix[4, 4]f32
Vertex :: struct {
  position: [2]f32,
}

Geometry :: struct {
  vertex: vk.Buffer,
  memory: vk.DeviceMemory,
  instance_offset: u32,
  instance_count: u32,
  count: u32,
}

create_geometries :: proc(ctx: ^VulkanContext) -> bool {
  ctx.geometries = make([]Geometry, 10, ctx.allocator)
  ctx.geometries_len = 0
  ctx.max_instances = 0

  ctx.uniform_buffer = vulkan_buffer_create(ctx.device, size_of(Projection), { .UNIFORM_BUFFER, .TRANSFER_DST }) or_return
  ctx.uniform_buffer_memory = vulkan_buffer_create_memory(ctx.device, ctx.physical_device, ctx.uniform_buffer, { .DEVICE_LOCAL }) or_return

  ctx.model_buffer = vulkan_buffer_create(ctx.device, vk.DeviceSize(size_of(InstanceModel) * 20), { .STORAGE_BUFFER, .TRANSFER_DST }) or_return
  ctx.model_buffer_memory = vulkan_buffer_create_memory(ctx.device, ctx.physical_device, ctx.model_buffer, { .DEVICE_LOCAL }) or_return

  ctx.color_buffer = vulkan_buffer_create(ctx.device, vk.DeviceSize(size_of([3]f32) * 20), { .STORAGE_BUFFER, .TRANSFER_DST }) or_return
  ctx.color_buffer_memory = vulkan_buffer_create_memory(ctx.device, ctx.physical_device, ctx.color_buffer, { .DEVICE_LOCAL }) or_return

  return true
}

add_geometry :: proc(ctx: ^VulkanContext, vertices: []Vertex, max_instances: u32) -> (geometry: ^Geometry, ok: bool) {
  geometry = &ctx.geometries[ctx.geometries_len]

  size := vk.DeviceSize(size_of(Vertex) * len(vertices))
  geometry.vertex = vulkan_buffer_create(ctx.device, size, { .VERTEX_BUFFER, .TRANSFER_DST }) or_return
  geometry.memory = vulkan_buffer_create_memory(ctx.device, ctx.physical_device, geometry.vertex, { .DEVICE_LOCAL }) or_return

  offset := vulkan_buffer_copy_data(Vertex, ctx, vertices[:])
  vulkan_buffer_copy(ctx, geometry.vertex, size, 0, offset) or_return

  geometry.instance_offset = ctx.max_instances
  geometry.instance_count = 0
  geometry.count = u32(len(vertices))
  ctx.max_instances += max_instances

  ctx.geometries_len += 1

  return geometry, true
}

add_geometry_instance :: proc(ctx: ^VulkanContext, geometry: ^Geometry, model: InstanceModel, color: [3]f32) -> (id: u32, ok: bool) {
  id = geometry.instance_count
  update_geometry_instance(ctx, geometry, id, model, color) or_return

  geometry.instance_count += 1

  return id, true
}

update_geometry_instance :: proc(ctx: ^VulkanContext, geometry: ^Geometry, id: u32, model: Maybe(InstanceModel), color: Maybe([3]f32)) -> bool{
  if model != nil {
    models := [?]InstanceModel{ model.? }

    offset := vulkan_buffer_copy_data(InstanceModel, ctx, models[:])
    vulkan_buffer_copy(ctx, ctx.model_buffer, size_of(InstanceModel), vk.DeviceSize(geometry.instance_offset + id) * size_of(InstanceModel), offset) or_return
  }

  if color != nil {
    colors := [?][3]f32{ color.? }

    offset := vulkan_buffer_copy_data([3]f32, ctx, colors[:])
    vulkan_buffer_copy(ctx, ctx.color_buffer, size_of([3]f32), vk.DeviceSize(geometry.instance_offset + id) * size_of([3]f32), offset) or_return
  }

  return true
}

destroy_geometry :: proc(device: vk.Device, geometry: ^Geometry) {
  vk.DestroyBuffer(device, geometry.vertex, nil)
  vk.FreeMemory(device, geometry.memory, nil)
}
