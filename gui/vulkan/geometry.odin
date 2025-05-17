package vulk

import vk "vendor:vulkan"
import "core:fmt"
import "core:math/linalg"
import "core:log"

import "./../collection"
import "./../error"

Instance_Model :: matrix[4, 4]f32
Color :: [4]f32
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
  instances: collection.Vector(Instance),
  transform: Matrix,
  bones_offset: u32,
}

Geometry_Group :: struct {
  childs: collection.Vector(Geometry),
  instances: u32,
  set: ^Descriptor_Set,
}

geometry_group_create :: proc(ctx: ^Vulkan_Context, layout: ^Pipeline_Layout, infos: []Descriptor_Info, count: u32) -> (group: Geometry_Group, err: error.Error) {
  group.set = descriptor_set_allocate(ctx, &ctx.descriptor_pool, layout.sets.data[1], infos) or_return
  group.childs = collection.new_vec(Geometry, count, ctx.allocator) or_return
  group.instances = 0

  return group, nil
}

geometry_group_append :: proc(group: ^Geometry_Group, max: u32) -> (geometry: ^Geometry, err: error.Error) {
  geometry = collection.vec_one(&group.childs) or_return
  geometry.instance_offset = group.instances
  geometry.parent = group

  group.instances += max

  return geometry, nil
}

geometry_create :: proc(ctx: ^Vulkan_Context, vertices: []u8, vertex_size: u32, vertex_count: u32, indices: []u8, index_size: u32, index_count: u32, max_instances: u32, transform: Matrix, animated: bool) -> (geometry: ^Geometry, err: error.Error) {
  if animated {
    geometry = geometry_group_append(&ctx.render_pass.pipelines.data[0].geometries, max_instances) or_return
  } else {
    geometry = geometry_group_append(&ctx.render_pass.pipelines.data[0].geometries, max_instances) or_return
  }

  geometry.transform = transform
  geometry.count = index_count
  geometry.bones_offset = ctx.bones

  geometry.instances = collection.new_vec(Instance, max_instances, ctx.allocator) or_return

  geometry.vertex = buffer_create(ctx, vertex_size * vertex_count, {.VERTEX_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}) or_return
  copy_data(u8, ctx, vertices, geometry.vertex.handle, 0) or_return

  geometry.indice = buffer_create(ctx, index_size * index_count, {.INDEX_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}) or_return
  copy_data(u8, ctx, indices, geometry.indice.handle, 0) or_return

  return geometry, nil
}

geometry_instance_add :: proc(ctx: ^Vulkan_Context, geometry: ^Geometry, model: Maybe(Instance_Model), color: Color) -> (instance: ^Instance, ok: error.Error) {
  offset := geometry.instance_offset + geometry.instances.len

  instance = collection.vec_one(&geometry.instances) or_return
  instance.geometry = geometry
  instance.offset = offset

  m := model.? or_else linalg.MATRIX4F32_IDENTITY

  instance_update(ctx, instance, m * geometry.transform, color) or_return

  return instance, nil
}

instance_update :: proc(ctx: ^Vulkan_Context, instance: ^Instance, model: Maybe(Instance_Model), color: Maybe(Color)) -> error.Error {
  if model != nil {
    models := [?]Instance_Model{model.?}
    copy_data(Instance_Model, ctx, models[:], instance.geometry.parent.set.descriptors[MODELS].buffer.handle, instance.offset) or_return
  }

  if color != nil {
    colors := [?]Color{color.?}
    copy_data(Color, ctx, colors[:], instance.geometry.parent.set.descriptors[COLORS].buffer.handle, instance.offset) or_return
  }

  return nil
}

destroy_geometry :: proc(ctx: ^Vulkan_Context, geometry: ^Geometry) {
  buffer_destroy(ctx, geometry.vertex)
  buffer_destroy(ctx, geometry.indice)
}
