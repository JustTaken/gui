package gltf

import "core:encoding/json"
import "core:math/linalg"
import "./../../error"

Gltf_Node :: struct {
  name: string,
  mesh: Maybe(Gltf_Mesh),
  children: []u32,
  skin: Maybe(u32),
  transform: Matrix,
}

parse_node :: proc(ctx: ^Gltf_Context, raw: json.Object) -> (node: Gltf_Node, err: error.Error) {
  node.name = raw["name"].(string)

  if mesh, ok := raw["mesh"]; ok {
    node.mesh = parse_mesh(ctx, ctx.raw_meshes[u32(mesh.(f64))].(json.Object)) or_return
  }

  node.transform = matrix[4, 4]f32 {
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
  }

  if translation, ok := raw["translation"]; ok {
    t := translation.(json.Array)

    for i in 0..<len(t) {
      node.transform[i, 3] = cast(f32)t[i].(f64)
    }
  }

  if scale, ok := raw["scale"]; ok {
    s := scale.(json.Array)

    for i in 0..<len(s) {
      node.transform[i, i] = cast(f32)s[i].(f64)
    }
  }

  if rotation, ok := raw["rotation"]; ok {
    r := rotation.(json.Array)
    q: quaternion128 = quaternion(x = cast(f32)r[0].(f64), y = -cast(f32)r[1].(f64), z = -cast(f32)r[2].(f64), w = cast(f32)r[3].(f64))
    mat := linalg.matrix3_from_quaternion_f32(q)
    node.transform = linalg.matrix4_from_matrix3_f32(mat) * node.transform
  }

  if children, ok := raw["children"]; ok {
    array := children.(json.Array)
    node.children = make([]u32, len(array), ctx.tmp_allocator)

    for i in 0..<len(array) {
      node.children[i] = u32(array[i].(f64))
    }
  }

  if skin, ok := raw["skin"]; ok {
    node.skin = u32(skin.(f64))
  }

  return node, nil
}

parse_nodes :: proc(ctx: ^Gltf_Context) -> (nodes: []Gltf_Node, err: error.Error) {
  raw_nodes := ctx.obj["nodes"].(json.Array)
  nodes = make([]Gltf_Node, len(raw_nodes), ctx.tmp_allocator)

  for i in 0..<len(raw_nodes) {
    nodes[i] = parse_node(ctx, raw_nodes[i].(json.Object)) or_return
  }

  return nodes, nil
}
