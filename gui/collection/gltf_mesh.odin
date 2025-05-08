package collection

import "core:encoding/json"
import "./../error"
import "base:runtime"

// Gltf_Target :: []Gltf_Attribute

Gltf_Material :: struct {
  name: string,
  double_sided: bool,
  metallic_roughness: []f64,
  metallic_factor: f64,
  roughness_factor: f64,
}

Gltf_Mesh_Primitive :: struct {
  accessors: [Gltf_Accessor_Kind]Maybe(Gltf_Accessor),
  indices: Maybe(Gltf_Accessor),
  // targets: []Gltf_Target,
  material: Gltf_Material,
}

Gltf_Mesh :: struct {
  name: string,
  primitives: []Gltf_Mesh_Primitive,
}

get_vertex_data :: proc(mesh: ^Gltf_Mesh, kinds: []Gltf_Accessor_Kind, allocator: runtime.Allocator) -> Vertex_Data {
  data: Vertex_Data
  data.size = 0
  data.count = 0

  count: u32 = 0

  sizes := make([]u32, len(kinds), allocator)

  for i in 0..<len(kinds) {
    accessor := mesh.primitives[0].accessors[kinds[i]].?
    sizes[i] = accessor.component_size * get_accessor_component_size(accessor.component)
    count += sizes[i] * accessor.count
    data.count = accessor.count
    data.size += sizes[i]
  }

  data.bytes = make([]u8, count, allocator)

  l: u32 = 0
  for i in 0..<data.count {
    for k in 0..<len(kinds) {
      start := i * sizes[k]
      end := sizes[k] + start

      copy(data.bytes[l:], mesh.primitives[0].accessors[kinds[k]].?.bytes[start:end])
      l += end - start
    }
  }

  assert(u32(l) == count)

  return data
}

get_mesh_indices :: proc(mesh: ^Gltf_Mesh) -> Vertex_Data {
  data: Vertex_Data
  indices := mesh.primitives[0].indices.?

  data.size = indices.component_size * get_accessor_component_size(indices.component) 
  data.count = indices.count
  data.bytes = indices.bytes

  return data
}

parse_material :: proc(ctx: ^Gltf_Context, raw: json.Object) -> (material: Gltf_Material, err: error.Error) {
  material.name = raw["name"].(string)
  material.double_sided = raw["doubleSided"].(bool)

  if attrib, ok := raw["pbrMetallicRoughness"]; ok {
    factor := attrib.(json.Object)["baseColorFactor"].(json.Array)
    material.metallic_roughness = make([]f64, len(factor), ctx.tmp_allocator)

    for i in 0..<len(factor) {
      material.metallic_roughness[i] = factor[i].(f64)
    }
  }

  if attrib, ok := raw["metallicFactor"]; ok {
    material.metallic_factor = attrib.(f64)
  }

  if attrib, ok := raw["roughnessFactor"]; ok {
    material.roughness_factor = attrib.(f64)
  }

  return material, nil
}

parse_mesh_primitive :: proc(ctx: ^Gltf_Context, raw: json.Object) -> (primitive: Gltf_Mesh_Primitive, err: error.Error) {
  raw_accessors := raw["attributes"].(json.Object)

  if attrib, ok := raw_accessors["POSITION"]; ok {
    index := u32(attrib.(f64))
    primitive.accessors[.Position] = ctx.accessors[index]
  }

  if attrib, ok := raw_accessors["NORMAL"]; ok {
    index := u32(attrib.(f64))
    primitive.accessors[.Normal] = ctx.accessors[index]
  }

  if attrib, ok := raw_accessors["COLOR_0"]; ok {
    index := u32(attrib.(f64))
    primitive.accessors[.Color0] = ctx.accessors[index]
  }

  if attrib, ok := raw_accessors["JOINTS_0"]; ok {
    index := u32(attrib.(f64))
    primitive.accessors[.Joint0] = ctx.accessors[index]
  }

  if attrib, ok := raw_accessors["WEIGHTS_0"]; ok {
    index := u32(attrib.(f64))
    primitive.accessors[.Weight0] = ctx.accessors[index]
  }

  if attrib, ok := raw_accessors["TEXCOORD_0"]; ok {
    index := u32(attrib.(f64))
    primitive.accessors[.Texture0] = ctx.accessors[index]
  }

  if attrib, ok := raw_accessors["TEXCOORD_1"]; ok {
    index := u32(attrib.(f64))
    primitive.accessors[.Texture1] = ctx.accessors[index]
  }

  if indices, ok := raw["indices"]; ok {
    index := u32(indices.(f64))
    primitive.indices = ctx.accessors[index]
  }

  {
    count: Maybe(u32)

    for attrib in primitive.accessors {
      if attrib == nil {
        continue
      }

      if count != nil && count.? != attrib.?.count {
        return primitive, .InvalidAccessorCount
      }

      count = attrib.?.count
    }
  }

  if material, ok := raw["material"]; ok {
    index := u32(material.(f64))
    primitive.material = parse_material(ctx, ctx.raw_materials[index].(json.Object)) or_return
  }

  return primitive, nil
}

parse_mesh :: proc(ctx: ^Gltf_Context, raw: json.Object) -> (mesh: Gltf_Mesh, err: error.Error) {
  mesh.name = raw["name"].(string)

  raw_primitives := raw["primitives"].(json.Array)
  mesh.primitives = make([]Gltf_Mesh_Primitive, len(raw_primitives), ctx.tmp_allocator)

  for i in 0..<len(raw_primitives) {
    mesh.primitives[i] = parse_mesh_primitive(ctx, raw_primitives[i].(json.Object)) or_return
  }

  return mesh, nil
}
