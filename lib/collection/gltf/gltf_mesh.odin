package gltf

import "base:runtime"
import "core:encoding/json"

import "lib:error"
import "lib:collection/vector"

Mesh_Primitive :: struct {
  accessors: [Accessor_Kind]^Accessor,
  indices: ^Accessor,
  material: Maybe(u32),
}

Mesh :: struct {
  name: string,
  primitives: vector.Vector(Mesh_Primitive),
}

// get_vertex_data :: proc(mesh: ^Mesh, kinds: []Accessor_Kind, allocator: runtime.Allocator) -> Vertex_Data {
//   data: Vertex_Data
//   data.size = 0
//   data.count = 0

//   count: u32 = 0

//   sizes := make([]u32, len(kinds), allocator)

//   for i in 0..<len(kinds) {
//     if accessor := mesh.primitives[0].accessors[kinds[i]]; accessor != nil {
//       sizes[i] = get_accessor_size(accessor)
//       count += sizes[i] * accessor.count
//       data.count = accessor.count
//       data.size += sizes[i]
//     }
//   }

//   data.bytes = make([]u8, count, allocator)

//   l: u32 = 0
//   for i in 0..<data.count {
//     for k in 0..<len(kinds) {
//       start := i * sizes[k]
//       end := sizes[k] + start

//       copy(data.bytes[l:], mesh.primitives[0].accessors[kinds[k]].bytes[start:end])
//       l += end - start
//     }
//   }

//   assert(u32(l) == count)

//   return data
// }

// get_mesh_indices :: proc(mesh: ^Mesh) -> Vertex_Data {
//   data: Vertex_Data
//   indices := mesh.primitives[0].indices

//   data.size = indices.component_size * get_accessor_component_size(indices.component) 
//   data.count = indices.count
//   data.bytes = indices.bytes

//   return data
// }

@private
parse_mesh_primitive :: proc(ctx: ^Context, raw: json.Object) -> (primitive: Mesh_Primitive, err: error.Error) {
  raw_accessors := raw["attributes"].(json.Object)

  if attrib, ok := raw_accessors["POSITION"]; ok do primitive.accessors[.Position] = &ctx.accessors.data[u32(attrib.(f64))]
  if attrib, ok := raw_accessors["NORMAL"]; ok do primitive.accessors[.Normal] = &ctx.accessors.data[u32(attrib.(f64))]
  if attrib, ok := raw_accessors["COLOR_0"]; ok do primitive.accessors[.Color0] = &ctx.accessors.data[u32(attrib.(f64))]
  if attrib, ok := raw_accessors["JOINTS_0"]; ok do primitive.accessors[.Joint0] = &ctx.accessors.data[u32(attrib.(f64))]
  if attrib, ok := raw_accessors["WEIGHTS_0"]; ok do primitive.accessors[.Weight0] = &ctx.accessors.data[u32(attrib.(f64))]
  if attrib, ok := raw_accessors["TEXCOORD_0"]; ok do primitive.accessors[.Texture0] = &ctx.accessors.data[u32(attrib.(f64))]
  if attrib, ok := raw_accessors["TEXCOORD_1"]; ok do primitive.accessors[.Texture1] = &ctx.accessors.data[u32(attrib.(f64))]

  if indices, ok := raw["indices"]; ok do primitive.indices = &ctx.accessors.data[u32(indices.(f64))]
  if material, ok := raw["material"]; ok do primitive.material = u32(material.(f64))

  return primitive, nil
}

@private
parse_mesh :: proc(ctx: ^Context, raw: json.Object) -> (mesh: Mesh, err: error.Error) {
  mesh.name = raw["name"].(string)

  raw_primitives := raw["primitives"].(json.Array)
  mesh.primitives = vector.new(Mesh_Primitive, u32(len(raw_primitives)), ctx.allocator) or_return

  for i in 0..<len(raw_primitives) {
    vector.append(&mesh.primitives, parse_mesh_primitive(ctx, raw_primitives[i].(json.Object)) or_return) or_return
  }

  return mesh, nil
}

@private
parse_meshes :: proc(ctx: ^Context) -> error.Error {
  for i in 0..<len(ctx.raw_meshes) {
    vector.append(&ctx.meshes, parse_mesh(ctx, ctx.raw_meshes[i].(json.Object)) or_return) or_return
  }

  return nil
}
