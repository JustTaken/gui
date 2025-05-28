package gltf

import "core:encoding/json"
import "core:math/linalg"
import "./../../error"
import "core:log"

Node :: struct {
  name: string,
  mesh: Maybe(u32),
  skin: Maybe(u32),
  parent: Maybe(u32),
  children: []u32,
  transform: Invertable_Transform,
  evaluated: bool,
  cascated: bool,
}

@private
parse_node :: proc(ctx: ^Context, n: int) -> error.Error {
  node := &ctx.nodes[n]

  if node.evaluated do return nil

  raw := ctx.raw_nodes[n].(json.Object)
  node.name = raw["name"].(string)

  node.transform.translate = {0, 0, 0}
  node.transform.rotate = {0, 0, 0, 0}
  node.transform.scale = {1, 1, 1}

  if scale, ok := raw["scale"]; ok {
    s := scale.(json.Array)

    node.transform.scale = {f32(s[0].(f64)), f32(s[1].(f64)), f32(s[2].(f64))}
  }

  if rotation, ok := raw["rotation"]; ok {
    r := rotation.(json.Array)
    node.transform.rotate = {f32(r[0].(f64)), f32(r[1].(f64)), f32(r[2].(f64)), f32(r[3].(f64))}
  }

  if translation, ok := raw["translation"]; ok {
    t := translation.(json.Array)

    node.transform.translate = {f32(t[0].(f64)), f32(t[1].(f64)), f32(t[2].(f64))}
  }

  invertable_transform_apply(&node.transform)

  if mesh, ok := raw["mesh"]; ok {
    node.mesh = u32(mesh.(f64))
  }

  if skin, ok := raw["skin"]; ok {
    node.skin = u32(skin.(f64))
  }

  if children, ok := raw["children"]; ok {
    array := children.(json.Array)

    node.children = make([]u32, len(array), ctx.allocator)

    for i in 0..<len(array) {
      index := int(array[i].(f64))
      node.children[i] = u32(index)

      parse_node(ctx, index) or_return
      ctx.nodes[index].parent = u32(n)
    }
  }

  node.evaluated = true

  return nil
}

@private
evaluate_node :: proc(ctx: ^Context, n: int) {
  if ctx.nodes[n].cascated do return

  ctx.nodes[n].transform.inverse = linalg.inverse(ctx.nodes[n].transform.compose)

  if ctx.nodes[n].parent != nil {
    evaluate_node(ctx, int(ctx.nodes[n].parent.?))

    ctx.nodes[n].transform.compose = ctx.nodes[ctx.nodes[n].parent.?].transform.compose * ctx.nodes[n].transform.compose
  }


  log.info("NODE:", n, ctx.nodes[n].name, ctx.nodes[n].parent)
  log.info("  TRANSLATE", ctx.nodes[n].transform.translate)
  log.info("  ROTATE", ctx.nodes[n].transform.rotate)
  log.info("  SCALE", ctx.nodes[n].transform.scale)
  log.info("  TRANSFORM", ctx.nodes[n].transform.compose)
  log.info("  INVERSE", ctx.nodes[n].transform.inverse)

  for i in 0..<len(ctx.animations) {
    for k in 0..<len(ctx.animations[i].frames) {
      transforms := ctx.animations[i].frames[k].transforms
      transform := &ctx.animations[i].frames[k].transforms[n]

      transform_apply(transform)
      transform.compose = ctx.nodes[n].transform.inverse * transform.compose

      if ctx.nodes[n].parent != nil {
        transform.compose = transforms[ctx.nodes[n].parent.?].compose * transform.compose 
      }
    }
  }

  ctx.nodes[n].cascated = true
}

@private
parse_nodes :: proc(ctx: ^Context) -> error.Error {
  for i in 0..<len(ctx.raw_nodes) {
    parse_node(ctx, len(ctx.raw_nodes) - i - 1) or_return
  }

  for i in 0..<len(ctx.nodes) {
    evaluate_node(ctx, i)
  }

  for j in 0..<len(ctx.animations) {
    for k in 0..<len(ctx.animations[j].frames) {
      log.info("FRAME", k)

      for i in 0..<len(ctx.nodes) {
        transform := &ctx.animations[j].frames[k].transforms[i]

        log.info("  NODE", i, "PARENT:", ctx.nodes[i].parent)
        log.info("    TRANSLATE", transform.translate)
        log.info("    ROTATE", transform.rotate)
        log.info("    SCALE", transform.scale)
        log.info("    TRANSFORM", transform.compose)
        // log.info("    INVERSE", ctx.nodes[i].transform.inverse * transform.compose)
        // log.info("    INVERSE", transform.inverse * transform.compose)

        // transform.inverse = transform.inverse * transform.compose
      }
    }
  }

  return nil
}
