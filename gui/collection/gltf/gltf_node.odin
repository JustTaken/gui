package gltf

import "core:encoding/json"
import "core:math/linalg"
import "./../../error"
import "core:log"

Node :: struct {
  name: string,
  mesh: ^Mesh,
  children: []^Node,
  skin: ^Skin,
  transform: Matrix,
}

@private
parse_node :: proc(ctx: ^Context, raw: json.Object) -> (node: Node, err: error.Error) {
  node.name = raw["name"].(string)

  if mesh, ok := raw["mesh"]; ok {
    node.mesh = &ctx.meshes[u32(mesh.(f64))]
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

    node.children = make([]^Node, len(array), ctx.allocator)

    for i in 0..<len(array) {
      node.children[i] = &ctx.nodes[u32(array[i].(f64))]
    }
  }

  if skin, ok := raw["skin"]; ok {
    node.skin = &ctx.skins[u32(skin.(f64))]
  }

  return node, nil
}

@private
apply_node_transform :: proc(node: ^Node, parent: ^Node) {
  if parent != nil {
    node.transform = node.transform * parent.transform
  }

  for child in node.children {
    apply_node_transform(child, node)
  }
}

@private
parse_nodes :: proc(ctx: ^Context) -> error.Error {
  for i in 0..<len(ctx.raw_nodes) {
    ctx.nodes[i] = parse_node(ctx, ctx.raw_nodes[i].(json.Object)) or_return
  }

  return nil
}
