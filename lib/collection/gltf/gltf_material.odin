package gltf

import "core:encoding/json"
import "core:log"

import "lib:collection/vector"
import "lib:error"

Material :: struct {
  name:             string,
  double_sided:     bool,
  color:            [4]f32,
  metallic_factor:  f64,
  roughness_factor: f64,
}

@(private)
parse_material :: proc(
  ctx: ^Context,
  raw: json.Object,
) -> (
  material: Material,
  err: error.Error,
) {
  material.name = raw["name"].(string)
  material.double_sided = raw["doubleSided"].(bool)

  if rough, ok := raw["pbrMetallicRoughness"]; ok {
    metallic := rough.(json.Object)

    if color, ok := metallic["baseColorFactor"]; ok {
      factor := color.(json.Array)

      material.color = {
        f32(factor[0].(f64)),
        f32(factor[1].(f64)),
        f32(factor[2].(f64)),
        f32(factor[3].(f64)),
      }
    } else {
      material.color = {1, 1, 1, 1}
    }

    if factor, ok := metallic["metallicFactor"]; ok {
      material.metallic_factor = factor.(f64)
    } else {
      material.metallic_factor = 0
    }

    if factor, ok := metallic["roughnessFactor"]; ok {
      material.roughness_factor = factor.(f64)
    } else {
      material.roughness_factor = 0.5
    }
  }

  return material, nil
}

@(private)
parse_materials :: proc(ctx: ^Context) -> error.Error {
  for i in 0 ..< len(ctx.raw_materials) {
    vector.append(
      &ctx.materials,
      parse_material(ctx, ctx.raw_materials[i].(json.Object)) or_return,
    ) or_return
  }

  return nil
}
