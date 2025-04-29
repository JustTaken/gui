package vulk

import vk "vendor:vulkan"
import "./../collection"

TRANSFORMS :: 0
MODELS :: 1
COLORS :: 2
LIGHTS :: 3

Geometry :: struct {
  vertex:    Buffer,
  indice:    Buffer,
  count:     u32,
  instance_offset: u32,
  instance_count:  u32,
}

geometry_create :: proc(ctx: ^Vulkan_Context, vertices: []Vertex, indices: []u16, max_instances: u32) -> (id: u32, err: Error) {
  geometry: Geometry

  size := vk.DeviceSize(size_of(Vertex) * len(vertices))
  geometry.vertex = buffer_create(ctx, size, {.VERTEX_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}) or_return
  vulkan_copy_data(Vertex, ctx, vertices[:], geometry.vertex.handle, 0) or_return

  size = vk.DeviceSize(size_of(u16) * len(indices))
  geometry.indice = buffer_create(ctx, size, {.INDEX_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}) or_return
  vulkan_copy_data(u16, ctx, indices[:], geometry.indice.handle, 0) or_return

  geometry.instance_offset = ctx.max_instances
  geometry.instance_count = 0
  geometry.count = u32(len(indices))

  ctx.max_instances += max_instances
  id = ctx.geometries.len
  collection.vec_append(&ctx.geometries, geometry)

  return id, nil
}

geometry_add_instance :: proc(ctx: ^Vulkan_Context, geometry_id: u32, model: InstanceModel, color: Color) -> (id: u32, ok: Error) {
  geometry := &ctx.geometries.data[geometry_id]
  id = geometry.instance_count

  geometry_update_instance(ctx, geometry_id, id, model, color) or_return
  geometry.instance_count += 1

  return id, nil
}

geometry_update_instance :: proc(ctx: ^Vulkan_Context, geometry_id: u32, id: u32, model: Maybe(InstanceModel), color: Maybe(Color)) -> Error {
  geometry := &ctx.geometries.data[geometry_id]

  if model != nil {
    models := [?]InstanceModel{model.?}
    vulkan_copy_data(InstanceModel, ctx, models[:], ctx.descriptor_set.descriptors[MODELS].buffer.handle, vk.DeviceSize(geometry.instance_offset + id) * size_of(InstanceModel)) or_return
  }

  if color != nil {
    colors := [?]Color{color.?}
    vulkan_copy_data(Color, ctx, colors[:], ctx.descriptor_set.descriptors[COLORS].buffer.handle, vk.DeviceSize(geometry.instance_offset + id) * size_of(Color)) or_return
  }

  return nil
}

destroy_geometry :: proc(device: vk.Device, geometry: ^Geometry) {
  vk.DestroyBuffer(device, geometry.vertex.handle, nil)
  vk.FreeMemory(device, geometry.vertex.memory, nil)
  vk.DestroyBuffer(device, geometry.indice.handle, nil)
  vk.FreeMemory(device, geometry.indice.memory, nil)
}
