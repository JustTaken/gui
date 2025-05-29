package gltf

import "core:encoding/json"
import "core:log"

import "lib:error"
import "lib:collection/vector"

Scene :: struct {
  nodes: vector.Vector(u32),
}

@private
parse_scene :: proc(ctx: ^Context, raw: json.Object) -> (name: string, scene: Scene, err: error.Error) {
  name = raw["name"].(string)

  raw_nodes := raw["nodes"].(json.Array)
  scene.nodes = vector.new(u32, u32(len(raw_nodes)), ctx.allocator) or_return

  for i in 0..<len(raw_nodes) {
    vector.append(&scene.nodes, u32(raw_nodes[i].(f64))) or_return
  }

  return name, scene, nil
}

@private
parse_scenes :: proc(ctx: ^Context) -> error.Error {
  for i in 0..<len(ctx.raw_scenes) {
    name, scene := parse_scene(ctx, ctx.raw_scenes[i].(json.Object)) or_return
    ctx.scenes[name] = scene
  }

  return nil
}
