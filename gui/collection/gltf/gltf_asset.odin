package gltf

import "core:encoding/json"
import "core:math/linalg"
import "./../../error"

Asset :: struct {
  generator: string,
  version: string,
}

@private
parse_asset :: proc(ctx: ^Context) -> error.Error {
  raw := ctx.obj["asset"].(json.Object)

  ctx.asset.generator = raw["generator"].(string)
  ctx.asset.version = raw["version"].(string)

  ctx.raw_meshes = ctx.obj["meshes"].(json.Array)
  ctx.meshes = make([]Mesh, len(ctx.raw_meshes), ctx.allocator)

  ctx.raw_accessors = ctx.obj["accessors"].(json.Array)
  ctx.accessors = make([]Accessor, len(ctx.raw_accessors), ctx.allocator)

  ctx.raw_nodes = ctx.obj["nodes"].(json.Array)
  ctx.nodes = make([]Node, len(ctx.raw_nodes), ctx.allocator)
  ctx.inverse_binding = make([]Matrix, len(ctx.raw_nodes), ctx.allocator)

  for i in 0..<len(ctx.raw_nodes) {
    ctx.inverse_binding[i] = linalg.MATRIX4F32_IDENTITY
  }

  ctx.raw_buffer_views = ctx.obj["bufferViews"].(json.Array)
  ctx.buffer_views = make([]Buffer_View, len(ctx.raw_buffer_views), ctx.allocator)

  ctx.raw_buffers = ctx.obj["buffers"].(json.Array)
  ctx.buffers = make([]Buffer, len(ctx.raw_buffers), ctx.allocator)

  ctx.raw_scenes = ctx.obj["scenes"].(json.Array)
  ctx.scenes = make(map[string]Scene, len(raw) * 2, ctx.allocator)

  if raw_animations, ok := ctx.obj["animations"]; ok {
    ctx.raw_animations = raw_animations.(json.Array)
    ctx.animations = make([]Animation, len(ctx.raw_animations), ctx.allocator)
  }

  if raw_skins, ok := ctx.obj["skins"]; ok {
    ctx.raw_skins = raw_skins.(json.Array)
    ctx.skins = make([]Skin, len(ctx.raw_skins), ctx.allocator)
  }

  if materials, ok := ctx.obj["materials"]; ok {
    ctx.raw_materials = materials.(json.Array)
    ctx.materials = make([]Material, len(ctx.raw_materials), ctx.allocator)
  }

  return nil
}
