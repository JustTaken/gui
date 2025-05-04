package vulk

import vk "vendor:vulkan"
import "./../collection"
import "core:fmt"

TRANSFORMS :: 0
MODELS :: 1
COLORS :: 2
LIGHTS :: 3

Instance :: struct {
  model:       InstanceModel,
}

Geometry :: struct {
  vertex:    Buffer,
  indice:    Buffer,
  count: u32,
  offset: u32,
  instances: u32,
}

geometry_create :: proc(ctx: ^Vulkan_Context, vertices: []u8, vertex_size: u32, vertex_count: u32, indices: []u8, index_size: u32, index_count: u32, max_instances: u32) -> (id: u32, err: Error) {
  geometry: Geometry

  geometry.vertex = buffer_create(ctx, vk.DeviceSize(vertex_size * vertex_count), {.VERTEX_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}) or_return
  vulkan_copy_data(u8, ctx, vertices, geometry.vertex.handle, 0) or_return

  geometry.indice = buffer_create(ctx, vk.DeviceSize(index_size * index_count), {.INDEX_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}) or_return
  vulkan_copy_data(u8, ctx, indices, geometry.indice.handle, 0) or_return

  geometry.count = index_count
  geometry.offset = ctx.instances.len
  geometry.instances = 0
  ctx.instances.len += max_instances

  id = ctx.geometries.len
  collection.vec_append(&ctx.geometries, geometry)

  return id, nil
}

geometry_instance_add :: proc(ctx: ^Vulkan_Context, geometry_id: u32, model: InstanceModel, color: Color) -> (id: u32, ok: Error) {
  geometry := &ctx.geometries.data[geometry_id]
  id = geometry.offset + geometry.instances

  instance: Instance
  instance.model = model

  instance_update(ctx, id, model, color) or_return
  geometry.instances += 1

  return id, nil
}

instance_update :: proc(ctx: ^Vulkan_Context, id: u32, model: Maybe(InstanceModel), color: Maybe(Color)) -> Error {
  if model != nil {
    models := [?]InstanceModel{model.?}
    vulkan_copy_data(InstanceModel, ctx, models[:], ctx.descriptor_set.descriptors[MODELS].buffer.handle, vk.DeviceSize(id) * size_of(InstanceModel)) or_return
  }

  if color != nil {
    colors := [?]Color{color.?}
    vulkan_copy_data(Color, ctx, colors[:], ctx.descriptor_set.descriptors[COLORS].buffer.handle, vk.DeviceSize(id) * size_of(Color)) or_return
  }

  return nil
}

destroy_geometry :: proc(device: vk.Device, geometry: ^Geometry) {
  vk.DestroyBuffer(device, geometry.vertex.handle, nil)
  vk.FreeMemory(device, geometry.vertex.memory, nil)
  vk.DestroyBuffer(device, geometry.indice.handle, nil)
  vk.FreeMemory(device, geometry.indice.memory, nil)
}
