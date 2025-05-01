package vulk

import vk "vendor:vulkan"
import "./../collection"

TRANSFORMS :: 0
MODELS :: 1
COLORS :: 2
LIGHTS :: 3

Instance :: struct {
  // geometry: ^Geometry,
  model:       InstanceModel,
  // id: u32,
}

Geometry :: struct {
  vertex:    Buffer,
  indice:    Buffer,
  // instances: collection.Vector(Instance),
  count: u32,
  offset: u32,
  instances: u32,
}

geometry_create :: proc(ctx: ^Vulkan_Context, vertices: []Vertex, indices: []u16, max_instances: u32) -> (id: u32, err: Error) {
  geometry: Geometry

  size := vk.DeviceSize(size_of(Vertex) * len(vertices))
  geometry.vertex = buffer_create(ctx, size, {.VERTEX_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}) or_return
  vulkan_copy_data(Vertex, ctx, vertices[:], geometry.vertex.handle, 0) or_return

  size = vk.DeviceSize(size_of(u16) * len(indices))
  geometry.indice = buffer_create(ctx, size, {.INDEX_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}) or_return
  vulkan_copy_data(u16, ctx, indices[:], geometry.indice.handle, 0) or_return

  geometry.count = u32(len(indices))
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
