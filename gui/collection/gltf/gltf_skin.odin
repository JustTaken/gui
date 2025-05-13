package gltf

import "core:encoding/json"
import "./../../error"

Gltf_Skin :: struct {
  matrices: []Matrix,
  joints: []u32,
  skeleton: Maybe(u32),
}

parse_skin :: proc(ctx: ^Gltf_Context, raw: json.Object) -> (skin: Gltf_Skin, err: error.Error) {
  raw_matrices := &ctx.accessors[u32(raw["inverseBindMatrices"].(f64))]

  ptr := cast([^]f32)&raw_matrices.bytes[0]

  skin.matrices = make([]Matrix, raw_matrices.count, ctx.tmp_allocator)

  for i in 0..<raw_matrices.count {
    m := ptr[i * 16:]
    skin.matrices[i] = Matrix {
      m[0], m[1], m[2], m[3],
      m[4], m[5], m[6], m[7],
      m[8], m[9], m[10], m[11],
      m[12], m[13], m[14], m[15],
    }
  }

  raw_joints := raw["joints"].(json.Array)
  skin.joints = make([]u32, len(raw_joints), ctx.tmp_allocator)

  for i in 0..<len(raw_joints) {
    skin.joints[i] = u32(raw_joints[i].(f64))
  }

  if skeleton, ok := raw["skeleton"]; ok {
    skin.skeleton = u32(skeleton.(f64))
  }

  return skin, nil
}

parse_skins :: proc(ctx: ^Gltf_Context) -> (skins: []Gltf_Skin, err: error.Error) {
  raw, ok := ctx.obj["skins"]

  if !ok {
    return nil, nil
  }

  raw_array := raw.(json.Array)
  skins = make([]Gltf_Skin, len(raw_array), ctx.tmp_allocator)

  for i in 0..<len(raw_array) {
    parse_skin(ctx, raw_array[i].(json.Object))
  }

  return skins, nil
}
