package gltf

import "base:runtime"
import "core:encoding/json"

import "lib:collection/vector"
import "lib:error"

Mesh_Primitive :: struct {
  accessors: [Accessor_Kind]^Accessor,
  indices:   ^Accessor,
  material:  Maybe(u32),
}

Mesh :: struct {
  name:       string,
  primitives: vector.Vector(Mesh_Primitive),
}

@(private)
parse_mesh_primitive :: proc(
  ctx: ^Context,
  raw: json.Object,
) -> (
  primitive: Mesh_Primitive,
  err: error.Error,
) {
  raw_accessors := raw["attributes"].(json.Object)

  if attrib, ok := raw_accessors["POSITION"]; ok {
    primitive.accessors[.Position] = &ctx.accessors.data[u32(attrib.(f64))]
  }

  if attrib, ok := raw_accessors["NORMAL"]; ok {
    primitive.accessors[.Normal] = &ctx.accessors.data[u32(attrib.(f64))]
  }

  if attrib, ok := raw_accessors["COLOR_0"]; ok {
    primitive.accessors[.Color0] = &ctx.accessors.data[u32(attrib.(f64))]
  }

  if attrib, ok := raw_accessors["JOINTS_0"]; ok {
    primitive.accessors[.Joint0] = &ctx.accessors.data[u32(attrib.(f64))]
  }

  if attrib, ok := raw_accessors["WEIGHTS_0"]; ok {
    primitive.accessors[.Weight0] = &ctx.accessors.data[u32(attrib.(f64))]
  }

  if attrib, ok := raw_accessors["TEXCOORD_0"]; ok {
    primitive.accessors[.Texture0] = &ctx.accessors.data[u32(attrib.(f64))]
  }

  if attrib, ok := raw_accessors["TEXCOORD_1"]; ok {
    primitive.accessors[.Texture1] = &ctx.accessors.data[u32(attrib.(f64))]
  }

  if indices, ok := raw["indices"]; ok {
    primitive.indices = &ctx.accessors.data[u32(indices.(f64))]
  }

  if material, ok := raw["material"]; ok {
    primitive.material = u32(material.(f64))
  }

  return primitive, nil
}

@(private)
parse_mesh :: proc(
  ctx: ^Context,
  raw: json.Object,
) -> (
  mesh: Mesh,
  err: error.Error,
) {
  mesh.name = raw["name"].(string)

  raw_primitives := raw["primitives"].(json.Array)

  mesh.primitives = vector.new(
    Mesh_Primitive,
    u32(len(raw_primitives)),
    ctx.allocator,
  ) or_return

  for i in 0 ..< len(raw_primitives) {
    vector.append(
      &mesh.primitives,
      parse_mesh_primitive(ctx, raw_primitives[i].(json.Object)) or_return,
    ) or_return
  }

  return mesh, nil
}

@(private)
parse_meshes :: proc(ctx: ^Context) -> error.Error {
  for i in 0 ..< len(ctx.raw_meshes) {
    vector.append(
      &ctx.meshes,
      parse_mesh(ctx, ctx.raw_meshes[i].(json.Object)) or_return,
    ) or_return
  }

  return nil
}
