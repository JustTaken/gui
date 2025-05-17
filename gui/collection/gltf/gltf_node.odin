package gltf

import "core:encoding/json"
import "core:math/linalg"
import "./../../error"
import "core:log"

Node :: struct {
  name: string,
  mesh: ^Mesh,
  children: []u32,
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

  if scale, ok := raw["scale"]; ok {
    s := scale.(json.Array)

    node.transform = linalg.matrix4_scale_f32({cast(f32)s[0].(f64), cast(f32)s[1].(f64), cast(f32)s[2].(f64)}) * node.transform
  }

  if rotation, ok := raw["rotation"]; ok {
    r := rotation.(json.Array)
    q: quaternion128 = quaternion(x = cast(f32)r[0].(f64), y = -cast(f32)r[1].(f64), z = -cast(f32)r[2].(f64), w = cast(f32)r[3].(f64))
    mat := linalg.matrix3_from_quaternion_f32(q)
    node.transform = node.transform * linalg.matrix4_from_matrix3_f32(mat)
  }

  if translation, ok := raw["translation"]; ok {
    t := translation.(json.Array)

    node.transform = linalg.matrix4_translate_f32({cast(f32)t[0].(f64), cast(f32)t[1].(f64), cast(f32)t[2].(f64)}) * node.transform
  }

  if children, ok := raw["children"]; ok {
    array := children.(json.Array)

    node.children = make([]u32, len(array), ctx.allocator)

    for i in 0..<len(array) {
      node.children[i] = u32(array[i].(f64))
    }
  }

  if skin, ok := raw["skin"]; ok {
    node.skin = &ctx.skins[u32(skin.(f64))]
  }

  return node, nil
}

@private
apply_node_transform :: proc(ctx: ^Context, node: u32, parent: Maybe(u32)) {
  if parent != nil {
    ctx.nodes[node].transform = ctx.nodes[parent.?].transform * ctx.nodes[node].transform
  }

  for i in 0..<len(ctx.fragmented_animations) {
    for k in 0..<len(ctx.fragmented_animations[i].frames) {
      frame := &ctx.fragmented_animations[i].frames[k]

      translate := linalg.matrix4_translate_f32(frame.transforms[node].translate)
      rotate := linalg.matrix4_from_quaternion_f32(quaternion(x = frame.transforms[node].rotate[0], y = frame.transforms[node].rotate[1], z = frame.transforms[node].rotate[2], w = frame.transforms[node].rotate[3]))
      scale := linalg.matrix4_scale_f32(frame.transforms[node].scale)

      ctx.animations[i].frames[k].transforms[node] = translate * rotate * scale

      if parent != nil {
        ctx.animations[i].frames[k].transforms[node] = ctx.animations[i].frames[k].transforms[parent.?] * ctx.animations[i].frames[k].transforms[node]
      }
    }
  }

  for child in ctx.nodes[node].children {
    apply_node_transform(ctx, child, node)
  }
}

@private
parse_nodes :: proc(ctx: ^Context) -> error.Error {
  for i in 0..<len(ctx.raw_nodes) {
    ctx.nodes[i] = parse_node(ctx, ctx.raw_nodes[i].(json.Object)) or_return
  }

  return nil
}
