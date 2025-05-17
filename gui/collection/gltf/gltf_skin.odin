package gltf

import "core:encoding/json"
import "./../../error"

Skin :: struct {
  matrices: []Matrix,
  joints: []u32,
  skeleton: Maybe(u32),
}

@private
parse_skin :: proc(ctx: ^Context, raw: json.Object) -> (skin: Skin, err: error.Error) {
  raw_joints := raw["joints"].(json.Array)
  skin.joints = make([]u32, len(raw_joints), ctx.allocator)

  for i in 0..<len(raw_joints) {
    skin.joints[i] = u32(raw_joints[i].(f64))
  }

  raw_matrices := &ctx.accessors[u32(raw["inverseBindMatrices"].(f64))]

  ptr := cast([^]f32)&raw_matrices.bytes[0]

  skin.matrices = make([]Matrix, raw_matrices.count, ctx.allocator)

  for i in 0..<raw_matrices.count {
    m := ptr[i * 16:]
    skin.matrices[i] = Matrix {
      m[0], m[1], m[2], m[3],
      m[4], m[5], m[6], m[7],
      m[8], m[9], m[10], m[11],
      m[12], m[13], m[14], m[15],
    }
  }

  if skeleton, ok := raw["skeleton"]; ok {
    skin.skeleton = u32(skeleton.(f64))
  }

  return skin, nil
}

@private
parse_skins :: proc(ctx: ^Context) -> error.Error {
  for i in 0..<len(ctx.raw_skins) {
    ctx.skins[i] = parse_skin(ctx, ctx.raw_skins[i].(json.Object)) or_return
  }

  return nil
}
