package vulk

import vk "vendor:vulkan"
import "core:fmt"

import "./../collection"
import "./../error"

TRANSFORMS :: 0
MODELS :: 1
COLORS :: 2
LIGHTS :: 3

InstanceModel :: matrix[4, 4]f32
Color :: [4]f32
Light :: [3]f32
Matrix :: matrix[4, 4]f32

IDENTITY := Matrix {
  1, 0, 0, 0,
  0, 1, 0, 0,
  0, 0, 1, 0,
  0, 0, 0, 1,
}

Geometry :: struct {
  vertex:    Buffer,
  indice:    Buffer,
  count: u32,
  offset: u32,
  instances: u32,
  transform: Matrix,
}

geometry_create :: proc(ctx: ^Vulkan_Context, vertices: []u8, vertex_size: u32, vertex_count: u32, indices: []u8, index_size: u32, index_count: u32, max_instances: u32, transform: Matrix) -> (id: u32, err: error.Error) {
  geometry: Geometry

  geometry.vertex = buffer_create(ctx, vk.DeviceSize(vertex_size * vertex_count), {.VERTEX_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}) or_return
  copy_data(u8, ctx, vertices, geometry.vertex.handle, 0) or_return

  geometry.indice = buffer_create(ctx, vk.DeviceSize(index_size * index_count), {.INDEX_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}) or_return
  copy_data(u8, ctx, indices, geometry.indice.handle, 0) or_return

  geometry.transform = transform
  geometry.count = index_count
  geometry.offset = ctx.instances
  geometry.instances = 0
  ctx.instances += max_instances

  id = ctx.geometries.len
  collection.vec_append(&ctx.geometries, geometry)

  return id, nil
}

geometry_instance_add :: proc(ctx: ^Vulkan_Context, geometry_id: u32, model: Maybe(InstanceModel), color: Color) -> (id: u32, ok: error.Error) {
  geometry := &ctx.geometries.data[geometry_id]
  id = geometry.offset + geometry.instances

  m := model.? or_else IDENTITY

  instance_update(ctx, id, m * geometry.transform, color) or_return
  geometry.instances += 1

  return id, nil
}

instance_update :: proc(ctx: ^Vulkan_Context, id: u32, model: Maybe(InstanceModel), color: Maybe(Color)) -> error.Error {
  if model != nil {
    models := [?]InstanceModel{model.?}
    copy_data(InstanceModel, ctx, models[:], ctx.descriptor_set.descriptors[MODELS].buffer.handle, vk.DeviceSize(id) * size_of(InstanceModel)) or_return
  }

  if color != nil {
    colors := [?]Color{color.?}
    copy_data(Color, ctx, colors[:], ctx.descriptor_set.descriptors[COLORS].buffer.handle, vk.DeviceSize(id) * size_of(Color)) or_return
  }

  return nil
}

destroy_geometry :: proc(device: vk.Device, geometry: ^Geometry) {
  vk.DestroyBuffer(device, geometry.vertex.handle, nil)
  vk.FreeMemory(device, geometry.vertex.memory, nil)
  vk.DestroyBuffer(device, geometry.indice.handle, nil)
  vk.FreeMemory(device, geometry.indice.memory, nil)
}
