package collection

import "core:encoding/json"

Gltf_Target :: []Gltf_Attribute

Gltf_Material_Metallic_Roughness :: struct {
  base_color_factor: []f64,
}

Gltf_Material :: struct {
  name: string,
  double_sided: bool,
  metallic_roughness: Gltf_Material_Metallic_Roughness,
  metallic_factor: f64,
  roughness_factor: f64,
}

Gltf_Mesh_Primitive :: struct {
  attributes: [Gltf_Attribute_Kind]Maybe(Gltf_Attribute),
  indices: Maybe(Gltf_Attribute),
  // targets: []Gltf_Target,
  material: Gltf_Material,
}

Gltf_Mesh :: struct {
  name: string,
  primitives: []Gltf_Mesh_Primitive,
}

get_mesh_attribute :: proc(mesh: ^Gltf_Mesh, kind: Gltf_Attribute_Kind) -> Gltf_Attribute {
  return mesh.primitives[0].attributes[kind].?
}

get_mesh_indices :: proc(mesh: ^Gltf_Mesh) -> Vertex_Data {
  data: Vertex_Data
  indices := mesh.primitives[0].indices.?

  data.size = indices.component_size * get_attribute_component_size(indices.component) 
  data.count = indices.count
  data.bytes = indices.bytes

  return data
}

parse_material :: proc(ctx: ^Gltf_Context, raw: json.Object) -> (material: Gltf_Material, err: Error) {
  material.name = raw["name"].(string)
  material.double_sided = raw["doubleSided"].(bool)

  if attrib, ok := raw["pbrMetallicRoughness"]; ok {
    factor := attrib.(json.Object)["baseColorFactor"].(json.Array)
    material.metallic_roughness.base_color_factor = make([]f64, len(factor), ctx.tmp_allocator)

    for i in 0..<len(factor) {
      material.metallic_roughness.base_color_factor[i] = factor[i].(f64)
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

parse_mesh_primitive :: proc(ctx: ^Gltf_Context, raw: json.Object) -> (primitive: Gltf_Mesh_Primitive, err: Error) {
  raw_attributes := raw["attributes"].(json.Object)

  if attrib, ok := raw_attributes["POSITION"]; ok {
    index := u32(attrib.(f64))
    primitive.attributes[.Position] = parse_attribute(ctx, ctx.raw_accessors[index].(json.Object)) or_return
  }

  if attrib, ok := raw_attributes["NORMAL"]; ok {
    index := u32(attrib.(f64))
    primitive.attributes[.Normal] = parse_attribute(ctx, ctx.raw_accessors[index].(json.Object)) or_return
  }

  if attrib, ok := raw_attributes["COLOR_0"]; ok {
    index := u32(attrib.(f64))
    primitive.attributes[.Color0] = parse_attribute(ctx, ctx.raw_accessors[index].(json.Object)) or_return
  }

  if attrib, ok := raw_attributes["JOINTS_0"]; ok {
    index := u32(attrib.(f64))
    primitive.attributes[.Joint0] = parse_attribute(ctx, ctx.raw_accessors[index].(json.Object)) or_return
  }

  if attrib, ok := raw_attributes["WEIGHTS_0"]; ok {
    index := u32(attrib.(f64))
    primitive.attributes[.Weight0] = parse_attribute(ctx, ctx.raw_accessors[index].(json.Object)) or_return
  }

  if attrib, ok := raw_attributes["TEXCOORD_0"]; ok {
    index := u32(attrib.(f64))
    primitive.attributes[.Texture0] = parse_attribute(ctx, ctx.raw_accessors[index].(json.Object)) or_return
  }

  if attrib, ok := raw_attributes["TEXCOORD_1"]; ok {
    index := u32(attrib.(f64))
    primitive.attributes[.Texture1] = parse_attribute(ctx, ctx.raw_accessors[index].(json.Object)) or_return
  }

  if indices, ok := raw["indices"]; ok {
    index := u32(indices.(f64))
    primitive.indices = parse_attribute(ctx, ctx.raw_accessors[index].(json.Object)) or_return
  }

  {
    count: Maybe(u32)

    for attrib in primitive.attributes {
      if attrib == nil {
        continue
      }

      if count != nil && count.? != attrib.?.count {
        return primitive, .InvalidAttributeCount
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

parse_mesh :: proc(ctx: ^Gltf_Context, raw: json.Object) -> (mesh: Gltf_Mesh, err: Error) {
  mesh.name = raw["name"].(string)

  raw_primitives := raw["primitives"].(json.Array)
  mesh.primitives = make([]Gltf_Mesh_Primitive, len(raw_primitives), ctx.tmp_allocator)

  for i in 0..<len(raw_primitives) {
    mesh.primitives[i] = parse_mesh_primitive(ctx, raw_primitives[i].(json.Object)) or_return
  }

  return mesh, nil
}
