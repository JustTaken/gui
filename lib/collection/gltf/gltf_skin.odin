package gltf

import "core:encoding/json"
import "core:log"

import "lib:error"
import "lib:collection/vector"

Skin :: struct {
  joints: vector.Vector(u32),
  skeleton: Maybe(u32),
}

@private
parse_skin :: proc(ctx: ^Context, raw: json.Object) -> (skin: Skin, err: error.Error) {
  raw_joints := raw["joints"].(json.Array)
  raw_matrices := &ctx.accessors.data[u32(raw["inverseBindMatrices"].(f64))]
  assert(raw_matrices.count == u32(len(raw_joints)))

  skin.joints = vector.new(u32, u32(len(raw_joints)), ctx.allocator) or_return

  ptr := (cast([^]f32)&raw_matrices.bytes[0])[0:raw_matrices.count * raw_matrices.component_count]

  for i in 0..<len(raw_joints) {
    joint := u32(raw_joints[i].(f64))
    vector.append(&skin.joints, joint) or_return

    m := ptr[i * 16:]

    // ctx.nodes[joint].transform.inverse = Matrix {
    //   m[0], m[4], m[8], m[12],
    //   m[1], m[5], m[9], m[13],
    //   m[2], m[6], m[10], m[14],
    //   m[3], m[7], m[11], m[15],
    // }

    // ctx.inverse_binding[joint] = Matrix {
    //   m[0], m[1], m[2], m[3],
    //   m[4], m[5], m[6], m[7],
    //   m[8], m[9], m[10], m[11],
    //   m[12], m[13], m[14], m[15],
    // }

    // log.info("Inverse binding:", joint, ctx.inverse_binding[joint])
  }

  if skeleton, ok := raw["skeleton"]; ok {
    skin.skeleton = u32(skeleton.(f64))
  }

  return skin, nil
}

@private
parse_skins :: proc(ctx: ^Context) -> error.Error {
  for i in 0..<len(ctx.raw_skins) {
    vector.append(&ctx.skins, parse_skin(ctx, ctx.raw_skins[i].(json.Object)) or_return) or_return
  }

  return nil
}
