package collection

import "core:encoding/json"
import "base:runtime"
import "core:fmt"

import "./../error"

Vertex_Data :: struct {
  bytes: []u8,
  size: u32,
  count: u32,
}

Gltf_Accessor_Kind :: enum {
  Position,
  Normal,
  Texture0,
  Texture1,
  Color0,
  Joint0,
  Weight0,
}

Gltf_Accessor_Component :: enum {
  F32,
  U16,
  U8,
}

Gltf_Accessor :: struct {
  component: Gltf_Accessor_Component,
  component_size: u32,

  bytes: []u8,
  count: u32,
}

parse_accessor :: proc(ctx: ^Gltf_Context, raw: json.Object) -> (accessor: Gltf_Accessor, err: error.Error) {
  raw_view := ctx.raw_buffer_views[u32(raw["bufferView"].(f64))].(json.Object)
  buffer := ctx.buffers[u32(raw_view["buffer"].(f64))]

  length := u32(raw_view["byteLength"].(f64))
  offset := u32(raw_view["byteOffset"].(f64))
  // target := u32(raw_view["target"].(f64))

  accessor.bytes = read_from_buffer(ctx, buffer, length, offset) or_return
  accessor.count = u32(raw["count"].(f64))

  switch u32(raw["componentType"].(f64)) {
    case 5126:
      accessor.component = .F32
    case 5123:
      accessor.component = .U16
    case 5121:
      accessor.component = .U8
    case:
      fmt.println("What is this accessor?", raw["componentType"].(f64))
      return accessor, .InvalidAccessorKind
  }

  switch raw["type"].(string) {
    case "MAT4":
      accessor.component_size = 16
    case "VEC4":
      accessor.component_size = 4
    case "VEC3":
      accessor.component_size = 3
    case "VEC2":
      accessor.component_size = 2
    case "SCALAR":
      accessor.component_size = 1
    case:
      return accessor, .InvalidAccessorKind
  }

  return accessor, nil
}

parse_accessors :: proc(ctx: ^Gltf_Context) -> (accessors: []Gltf_Accessor, err: error.Error) {
  raw_accessors := ctx.obj["accessors"].(json.Array)
  accessors = make([]Gltf_Accessor, len(raw_accessors), ctx.tmp_allocator)

  for i in 0..<len(raw_accessors) {
    accessors[i] = parse_accessor(ctx, raw_accessors[i].(json.Object)) or_return
  }

  return accessors, nil
}

get_accessor_component_size :: proc(kind: Gltf_Accessor_Component) -> u32 {
  switch kind {
    case .F32: return 4
    case .U16: return 2
    case .U8: return 1
  }

  panic("Invalid size")
}
