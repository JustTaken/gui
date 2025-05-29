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
  transform: Matrix,
  kind: Geometry_Kind,
}

geometry_create :: proc($T: typeid, ctx: ^Vulkan_Context, vertices: []T, indices: []u16, transform: Matrix, kind: Geometry_Kind) -> (geometry: ^Geometry, err: error.Error) {
  geometry = vector.one(&ctx.geometries) or_return
  geometry.kind = kind
  geometry.transform = transform
  geometry.count = u32(len(indices))

  geometry.vertex = buffer_create(ctx, u32(len(vertices) * size_of(T)), {.VERTEX_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}) or_return
  copy_data(T, ctx, vertices, geometry.vertex.handle, 0) or_return

  geometry.indice = buffer_create(ctx, u32(len(indices) * size_of(u16)), {.INDEX_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}) or_return
  copy_data(u16, ctx, indices, geometry.indice.handle, 0) or_return

  return geometry, nil
}

geometry_instance_add :: proc(ctx: ^Vulkan_Context, geometry: ^Geometry, model: Maybe(Instance_Model), method: Instance_Draw_Method) -> (instance: ^Instance, ok: error.Error) {
  pipeline: ^Pipeline

  switch method {
    case .WithView:
      switch geometry.kind {
        case .Unboned:
          pipeline = ctx.default_pipeline
        case .Boned:
          pipeline = ctx.boned_pipeline
      }
    case .WithoutView:
      switch geometry.kind {
        case .Unboned:
          pipeline = ctx.plain_pipeline
        case .Boned:
          panic("TODO")
      }
  }

  instance = pipeline_add_instance(ctx, pipeline, geometry, model) or_return

  return instance, nil
}

instance_update :: proc(ctx: ^Vulkan_Context, instance: ^Instance, model: Maybe(Instance_Model)) -> error.Error {
  if model != nil {
    models := [?]Instance_Model{model.? * instance.transform}
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
