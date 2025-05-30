package gltf

import "core:encoding/json"
import "core:math/linalg"

import "lib:collection/vector"
import "lib:error"

Asset :: struct {
  generator: string,
  version:   string,
}

@(private)
parse_asset :: proc(ctx: ^Context) -> error.Error {
  raw := ctx.obj["asset"].(json.Object)

  ctx.asset.generator = raw["generator"].(string)
  ctx.asset.version = raw["version"].(string)

  ctx.raw_meshes = ctx.obj["meshes"].(json.Array)
  ctx.meshes = vector.new(
    Mesh,
    u32(len(ctx.raw_meshes)),
    ctx.allocator,
  ) or_return

  ctx.raw_accessors = ctx.obj["accessors"].(json.Array)
  ctx.accessors = vector.new(
    Accessor,
    u32(len(ctx.raw_accessors)),
    ctx.allocator,
  ) or_return

  ctx.raw_nodes = ctx.obj["nodes"].(json.Array)
  ctx.nodes = vector.new(
    Node,
    u32(len(ctx.raw_nodes)),
    ctx.allocator,
  ) or_return
  vector.reserve_n(&ctx.nodes, u32(len(ctx.raw_nodes))) or_return

  ctx.raw_buffer_views = ctx.obj["bufferViews"].(json.Array)
  ctx.buffer_views = vector.new(
    Buffer_View,
    u32(len(ctx.raw_buffer_views)),
    ctx.allocator,
  ) or_return

  ctx.raw_buffers = ctx.obj["buffers"].(json.Array)
  ctx.buffers = vector.new(
    Buffer,
    u32(len(ctx.raw_buffers)),
    ctx.allocator,
  ) or_return

  ctx.raw_scenes = ctx.obj["scenes"].(json.Array)
  ctx.scenes = vector.new(
    Scene,
    u32(len(ctx.raw_scenes)),
    ctx.allocator,
  ) or_return

  if raw_animations, ok := ctx.obj["animations"]; ok {
    ctx.raw_animations = raw_animations.(json.Array)
    ctx.animations = vector.new(
      Animation,
      u32(len(ctx.raw_animations)),
      ctx.allocator,
    ) or_return
  }

  if raw_skins, ok := ctx.obj["skins"]; ok {
    ctx.raw_skins = raw_skins.(json.Array)
    ctx.skins = vector.new(
      Skin,
      u32(len(ctx.raw_skins)),
      ctx.allocator,
    ) or_return
  }

  if materials, ok := ctx.obj["materials"]; ok {
    ctx.raw_materials = materials.(json.Array)
    ctx.materials = vector.new(
      Material,
      u32(len(ctx.raw_materials)),
      ctx.allocator,
    ) or_return
  }

  return nil
}
