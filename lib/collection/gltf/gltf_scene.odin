package gltf

import "core:encoding/json"
import "core:log"

import "lib:collection/vector"
import "lib:error"

Scene :: struct {
  name:  string,
  nodes: vector.Vector(u32),
}

@(private)
parse_scene :: proc(
  ctx: ^Context,
  raw: json.Object,
) -> (
  scene: Scene,
  err: error.Error,
) {
  raw_nodes := raw["nodes"].(json.Array)

  scene.name = raw["name"].(string)
  scene.nodes = vector.new(u32, u32(len(raw_nodes)), ctx.allocator) or_return

  for i in 0 ..< len(raw_nodes) {
    vector.append(&scene.nodes, u32(raw_nodes[i].(f64))) or_return
  }

  return scene, nil
}

@(private)
parse_scenes :: proc(ctx: ^Context) -> error.Error {
  for i in 0 ..< len(ctx.raw_scenes) {
    vector.append(
      &ctx.scenes,
      parse_scene(ctx, ctx.raw_scenes[i].(json.Object)) or_return,
    ) or_return
  }

  return nil
}
