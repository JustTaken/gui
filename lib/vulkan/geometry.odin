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
Material :: [4]f32

Geometry_Kind :: enum {
  Boned,
  Unboned,
}

Instance_Draw_Method :: enum {
  WithView,
  WithoutView,
}

Instance :: struct {
  offset: u32,
  transform: Matrix,
}

Geometry :: struct {
  vertex: Buffer,
  indice: Buffer,
  count: u32,
  material: u32,
  transform: Matrix,
  kind: Geometry_Kind,
}

material_create :: proc(ctx: ^Vulkan_Context, color: [4]f32) -> (index: u32, err: error.Error) {
  index = ctx.materials.len

  material := color
  vector.append(&ctx.materials, material) or_return

  materials := [?]Material{material}
  copy_data(Material, ctx, materials[:], &ctx.dynamic_set.descriptors[MATERIALS].buffer, index) or_return

  return index, nil
}

geometry_create :: proc($T: typeid, ctx: ^Vulkan_Context, vertices: []T, indices: []u16, transform: Matrix, material: Maybe(u32), kind: Geometry_Kind) -> (index: u32, err: error.Error) {
  index = ctx.geometries.len

  geometry := vector.one(&ctx.geometries) or_return
  geometry.kind = kind
  geometry.transform = transform
  geometry.count = u32(len(indices))

  if material != nil {
    geometry.material = material.?
  } else {
    geometry.material = 0
  }

  geometry.vertex = buffer_create(ctx, u32(len(vertices) * size_of(T)), {.VERTEX_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}) or_return
  copy_data(T, ctx, vertices, &geometry.vertex, 0) or_return

  geometry.indice = buffer_create(ctx, u32(len(indices) * size_of(u16)), {.INDEX_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}) or_return
  copy_data(u16, ctx, indices, &geometry.indice, 0) or_return

  return index, nil
}

geometry_instance_add :: proc(ctx: ^Vulkan_Context, geometry_index: u32, model: Maybe(Instance_Model), method: Instance_Draw_Method) -> (instance: ^Instance, ok: error.Error) {
  pipeline: ^Pipeline

  switch method {
    case .WithView:
      switch ctx.geometries.data[geometry_index].kind {
        case .Unboned:
          pipeline = ctx.default_pipeline
        case .Boned:
          pipeline = ctx.boned_pipeline
      }
    case .WithoutView:
      switch ctx.geometries.data[geometry_index].kind {
        case .Unboned:
          pipeline = ctx.plain_pipeline
        case .Boned:
          panic("TODO")
      }
  }

  instance = pipeline_add_instance(ctx, pipeline, geometry_index, model) or_return

  return instance, nil
}

instance_update :: proc(ctx: ^Vulkan_Context, instance: ^Instance, model: Maybe(Instance_Model)) -> error.Error {
  if model != nil {
    models := [?]Instance_Model{model.? * instance.transform}
    copy_data(Instance_Model, ctx, models[:], &ctx.dynamic_set.descriptors[MODELS].buffer, instance.offset) or_return
  }

  return nil
}

add_transforms :: proc(ctx: ^Vulkan_Context, bones: []Matrix) -> (offset: u32, err: error.Error) {
  offset = ctx.bones
  ctx.bones += u32(len(bones))

  update_transforms(ctx, bones, offset) or_return

  return offset, nil
}

update_transforms :: proc(ctx: ^Vulkan_Context, bones: []Matrix, offset: u32) -> error.Error {
  copy_data(Matrix, ctx, bones, &ctx.dynamic_set.descriptors[DYNAMIC_TRANSFORMS].buffer, offset) or_return

  return nil
}

@private
destroy_geometry :: proc(ctx: ^Vulkan_Context, geometry: ^Geometry) {
  buffer_destroy(ctx, geometry.vertex)
  buffer_destroy(ctx, geometry.indice)
}
