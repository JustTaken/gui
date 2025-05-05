#+private
package collection

import "core:encoding/json"

Gltf_Scene :: struct {
  nodes: []Gltf_Node,
}

parse_scene :: proc(ctx: ^Gltf_Context, raw: json.Object) -> (name: string, scene: Gltf_Scene, err: Error) {
  name = raw["name"].(string)

  raw_nodes := raw["nodes"].(json.Array)
  scene.nodes = make([]Gltf_Node, len(raw_nodes), ctx.tmp_allocator)

  for i in 0..<len(raw_nodes) {
    index := u32(raw_nodes[i].(f64))
    scene.nodes[i] = ctx.nodes[index]
  }
  return name, scene, nil
}

parse_scenes :: proc(ctx: ^Gltf_Context) -> (scenes: map[string]Gltf_Scene, err: Error) {
  raw := ctx.obj["scenes"].(json.Array)
  scenes = make(map[string]Gltf_Scene, len(raw) * 2, ctx.allocator)

  for i in 0..<len(raw) {
    name, scene := parse_scene(ctx, raw[i].(json.Object)) or_return
    scenes[name] = scene
  }

  return scenes, nil
}

