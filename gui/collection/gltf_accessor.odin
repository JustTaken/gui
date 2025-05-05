package collection

import "core:encoding/json"
import "base:runtime"

Vertex_Data :: struct {
  bytes: []u8,
  size: u32,
  count: u32,
}

Gltf_Attribute_Kind :: enum {
  Position,
  Normal,
  Texture0,
  Texture1,
  Color0,
  Joint0,
  Weight0,
}

Gltf_Attribute_Component :: enum {
  F32,
  U16
}

Gltf_Attribute :: struct {
  component: Gltf_Attribute_Component,
  component_size: u32,

  bytes: []u8,
  count: u32,
}

parse_attribute :: proc(ctx: ^Gltf_Context, raw: json.Object) -> (attribute: Gltf_Attribute, err: Error) {
  raw_view := ctx.raw_buffer_views[u32(raw["bufferView"].(f64))].(json.Object)
  buffer := ctx.buffers[u32(raw_view["buffer"].(f64))]

  length := u32(raw_view["byteLength"].(f64))
  offset := u32(raw_view["byteOffset"].(f64))
  // target := u32(raw_view["target"].(f64))

  attribute.bytes = read_from_buffer(ctx, buffer, length, offset) or_return
  attribute.count = u32(raw["count"].(f64))

  switch u32(raw["componentType"].(f64)) {
    case 5126:
      attribute.component = .F32
    case 5123:
      attribute.component = .U16
    case:
      return attribute, .InvalidAttributeKind
  }

  switch raw["type"].(string) {
    case "MAT4":
      attribute.component_size = 16
    case "VEC4":
      attribute.component_size = 4
    case "VEC3":
      attribute.component_size = 3
    case "VEC2":
      attribute.component_size = 2
    case "SCALAR":
      attribute.component_size = 1
    case:
      return attribute, .InvalidAttributeKind
  }

  return attribute, nil
}

get_attribute_component_size :: proc(kind: Gltf_Attribute_Component) -> u32 {
  switch kind {
    case .F32: return 4
    case .U16: return 2
  }

  panic("Invalid size")
}

get_vertex_data :: proc(attributes: []Gltf_Attribute, allocator: runtime.Allocator) -> Vertex_Data {
  data: Vertex_Data
  data.size = 0
  data.count = 0

  count: u32 = 0

  sizes := make([]u32, len(attributes), allocator)

  for i in 0..<len(attributes) {
    sizes[i] = attributes[i].component_size * get_attribute_component_size(attributes[i].component)
    count += sizes[i] * attributes[i].count
    data.count = attributes[i].count
    data.size += sizes[i]
  }

  data.bytes = make([]u8, count, allocator)

  l: u32 = 0
  for i in 0..<data.count {
    for k in 0..<len(attributes) {
      start := i * sizes[k]
      end := sizes[k] + start

      copy(data.bytes[l:], attributes[k].bytes[start:end])
      l += end - start
    }
  }

  assert(u32(l) == count)

  return data
}

