#+private
package gltf

import "core:encoding/json"
import "./../../error"

Gltf_Scene :: struct {
  nodes: []u32,
  all_nodes: []Gltf_Node,
}

parse_scene :: proc(ctx: ^Gltf_Context, raw: json.Object) -> (name: string, scene: Gltf_Scene, err: error.Error) {
  name = raw["name"].(string)

  raw_nodes := raw["nodes"].(json.Array)
  scene.nodes = make([]u32, len(raw_nodes), ctx.allocator)
  scene.all_nodes = make([]Gltf_Node, len(ctx.nodes), ctx.allocator)

  for i in 0..<len(raw_nodes) {
    index := u32(raw_nodes[i].(f64))

    scene.nodes[i] = index
    node := ctx.nodes[index]

    include_node(ctx, &scene, node, index)
  }

  return name, scene, nil
}

include_node :: proc(ctx: ^Gltf_Context, scene: ^Gltf_Scene, node: Gltf_Node, index: u32) {
  scene.all_nodes[index] = node

  for child in node.children {
    include_node(ctx, scene, ctx.nodes[child], child)
  }
}

parse_scenes :: proc(ctx: ^Gltf_Context) -> (scenes: map[string]Gltf_Scene, err: error.Error) {
  raw := ctx.obj["scenes"].(json.Array)
  scenes = make(map[string]Gltf_Scene, len(raw) * 2, ctx.allocator)

  for i in 0..<len(raw) {
    name, scene := parse_scene(ctx, raw[i].(json.Object)) or_return
    scenes[name] = scene
  }

  return scenes, nil
}

