package gltf

import "core:encoding/json"
import "./../../error"
import "core:log"

Scene :: struct {
  nodes: []u32,
}

@private
parse_scene :: proc(ctx: ^Context, raw: json.Object) -> (name: string, scene: Scene, err: error.Error) {
  name = raw["name"].(string)

  raw_nodes := raw["nodes"].(json.Array)
  scene.nodes = make([]u32, len(raw_nodes), ctx.allocator)

  for i in 0..<len(raw_nodes) {
    index := u32(raw_nodes[i].(f64))

    scene.nodes[i] = index
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
