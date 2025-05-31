package vulk

import "core:fmt"
import "core:log"
import "core:math/linalg"
import vk "vendor:vulkan"

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
  offset:    u32,
  transform: Matrix,
}

Geometry :: struct {
  vertex:    Buffer,
  indice:    Buffer,
  count:     u32,
  material:  u32,
  transform: Matrix,
  kind:      Geometry_Kind,
}

geometry_create :: proc(
  $T: typeid,
  ctx: ^Vulkan_Context,
  vertices: []T,
  indices: []u16,
  transform: Matrix,
  material: Maybe(u32),
  kind: Geometry_Kind,
) -> (
  index: u32,
  err: error.Error,
) {
  index = ctx.geometries.len

  geometry := vector.one(&ctx.geometries) or_return
  geometry.kind = kind
  geometry.transform = transform
  geometry.count = u32(len(indices))

  geometry.material = material.? or_else ctx.default_material

  geometry.vertex = buffer_create(
    ctx,
    u32(len(vertices) * size_of(T)),
    {.VERTEX_BUFFER, .TRANSFER_DST},
    {.DEVICE_LOCAL},
  ) or_return
  copy_data_to_buffer(T, ctx, vertices, &geometry.vertex, 0) or_return

  geometry.indice = buffer_create(
    ctx,
    u32(len(indices) * size_of(u16)),
    {.INDEX_BUFFER, .TRANSFER_DST},
    {.DEVICE_LOCAL},
  ) or_return
  copy_data_to_buffer(u16, ctx, indices, &geometry.indice, 0) or_return

  return index, nil
}

geometry_instance_add :: proc(
  ctx: ^Vulkan_Context,
  geometry_index: u32,
  model: Maybe(Instance_Model),
  transform_offset: u32,
  method: Instance_Draw_Method,
) -> (
  instance: ^Instance,
  ok: error.Error,
) {
  pipeline: ^Pipeline
  offset: u32

  switch ctx.geometries.data[geometry_index].kind {
  case .Unboned:
    offset = transform_offset

    switch method {
    case .WithView:
      pipeline = ctx.default_pipeline
    case .WithoutView:
      pipeline = ctx.plain_pipeline
    }
  case .Boned:
    offset = 0

    switch method {
    case .WithView:
      pipeline = ctx.boned_pipeline
    case .WithoutView:
      panic("TODO")
    }
  }

  instance = pipeline_add_instance(
    ctx,
    pipeline,
    geometry_index,
    model,
    offset,
  ) or_return

  return instance, nil
}

instance_update :: proc(
  ctx: ^Vulkan_Context,
  instance: ^Instance,
  model: Maybe(Instance_Model),
) -> error.Error {
  if model != nil {
    models := [?]Instance_Model{model.? * instance.transform}
    descriptor_set_update(
      Instance_Model,
      ctx,
      ctx.dynamic_set,
      MODELS,
      models[:],
      instance.offset,
    ) or_return
  }

  return nil
}

add_transforms :: proc(
  ctx: ^Vulkan_Context,
  transforms: []Matrix,
) -> error.Error {
  update_transforms(ctx, transforms, ctx.transforms) or_return
  ctx.transforms += u32(len(transforms))

  return nil
}

update_transforms :: proc(
  ctx: ^Vulkan_Context,
  transforms: []Matrix,
  offset: u32,
) -> error.Error {
  descriptor_set_update(
    Instance_Model,
    ctx,
    ctx.dynamic_set,
    DYNAMIC_TRANSFORMS,
    transforms[:],
    offset,
  ) or_return

  return nil
}

@(private)
destroy_geometry :: proc(ctx: ^Vulkan_Context, geometry: ^Geometry) {
  buffer_destroy(ctx, geometry.vertex)
  buffer_destroy(ctx, geometry.indice)
}
