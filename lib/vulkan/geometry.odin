package vulk

import vk "vendor:vulkan"
import "core:fmt"
import "core:math/linalg"
import "core:log"

import "lib:collection/vector"
import "lib:error"

Instance_Model :: matrix[4, 4]f32
Light :: [3]f32
Matrix :: matrix[4, 4]f32

Instance :: struct {
  geometry: ^Geometry,
  offset: u32,
}

Geometry :: struct {
  parent: ^Geometry_Group,
  vertex:    Buffer,
  indice:    Buffer,
  count: u32,
  instance_offset: u32,
  instances: vector.Vector(Instance),
  transform: Matrix,
}

@private
Geometry_Group :: struct {
  childs: vector.Vector(Geometry),
}

@private
geometry_group_create :: proc(ctx: ^Vulkan_Context, set: ^Descriptor_Set, count: u32) -> (group: ^Geometry_Group, err: error.Error) {
  group = vector.one(&ctx.geometry_groups) or_return

  group.childs = vector.new(Geometry, count, ctx.allocator) or_return

  return group, nil
}

@private
geometry_group_append :: proc(group: ^Geometry_Group) -> (geometry: ^Geometry, err: error.Error) {
  geometry = vector.one(&group.childs) or_return
  geometry.parent = group

  return geometry, nil
}

geometry_create :: proc($T: typeid, ctx: ^Vulkan_Context, vertices: []T, indices: []u16, max_instances: u32, transform: Matrix, bonned_pipeline: bool) -> (geometry: ^Geometry, err: error.Error) {
  if bonned_pipeline {
    geometry = geometry_group_append(ctx.boned_group) or_return
  } else {
    geometry = geometry_group_append(ctx.default_group) or_return
  }

  geometry.instance_offset = ctx.instances
  geometry.transform = transform
  geometry.count = u32(len(indices))
  ctx.instances += max_instances

  geometry.instances = vector.new(Instance, max_instances, ctx.allocator) or_return

  geometry.vertex = buffer_create(ctx, u32(len(vertices) * size_of(T)), {.VERTEX_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}) or_return
  copy_data(T, ctx, vertices, geometry.vertex.handle, 0) or_return

  geometry.indice = buffer_create(ctx, u32(len(indices) * size_of(u16)), {.INDEX_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}) or_return
  copy_data(u16, ctx, indices, geometry.indice.handle, 0) or_return

  return geometry, nil
}

geometry_instance_add :: proc(ctx: ^Vulkan_Context, geometry: ^Geometry, model: Maybe(Instance_Model)) -> (instance: ^Instance, ok: error.Error) {
  offset := geometry.instance_offset + geometry.instances.len

  instance = vector.one(&geometry.instances) or_return
  instance.geometry = geometry
  instance.offset = offset

  m := model.? or_else linalg.MATRIX4F32_IDENTITY

  offsets := [?]u32{ctx.transforms}
  copy_data(u32, ctx, offsets[:], ctx.dynamic_set.descriptors[OFFSETS].buffer.handle, instance.offset) or_return

  instance_update(ctx, instance, m * geometry.transform) or_return

  return instance, nil
}

instance_update :: proc(ctx: ^Vulkan_Context, instance: ^Instance, model: Maybe(Instance_Model)) -> error.Error {
  if model != nil {
    models := [?]Instance_Model{model.?}
    copy_data(Instance_Model, ctx, models[:], ctx.dynamic_set.descriptors[MODELS].buffer.handle, instance.offset) or_return
  }

  return nil
}

add_transforms :: proc(ctx: ^Vulkan_Context, bones: []Matrix) -> (offset: u32, err: error.Error) {
  copy_data(Matrix, ctx, bones, ctx.dynamic_set.descriptors[DYNAMIC_TRANSFORMS].buffer.handle, ctx.bones) or_return
  offset = ctx.bones
  ctx.bones += u32(len(bones))

  return offset, nil
}

update_transforms :: proc(ctx: ^Vulkan_Context, bones: []Matrix, offset: u32) -> error.Error {
  if len(bones) > 0 {
    copy_data(Matrix, ctx, bones, ctx.dynamic_set.descriptors[DYNAMIC_TRANSFORMS].buffer.handle, offset) or_return
  }

  return nil
}

@private
destroy_geometry :: proc(ctx: ^Vulkan_Context, geometry: ^Geometry) {
  buffer_destroy(ctx, geometry.vertex)
  buffer_destroy(ctx, geometry.indice)
}
