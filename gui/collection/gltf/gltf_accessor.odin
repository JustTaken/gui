package gltf

import "core:encoding/json"
import "base:runtime"
import "core:fmt"

import "core:log"

import "./../../error"

Accessor_Kind :: enum {
  Position,
  Normal,
  Texture0,
  Texture1,
  Color0,
  Joint0,
  Weight0,
}

Accessor_Component :: enum {
  F32,
  U16,
  U8,
}

Accessor :: struct {
  component_kind: Accessor_Component,
  component_count: u32,

  bytes: []u8,
  count: u32,
}

@private
parse_accessor :: proc(ctx: ^Context, raw: json.Object) -> (accessor: Accessor, err: error.Error) {
  view  := &ctx.buffer_views[u32(raw["bufferView"].(f64))]

  accessor.bytes = view.buffer.bytes[view.offset:view.offset + view.length]
  accessor.count = u32(raw["count"].(f64))

  switch u32(raw["componentType"].(f64)) {
    case 5126: accessor.component_kind = .F32
    case 5123: accessor.component_kind = .U16
    case 5121: accessor.component_kind = .U8
    case:
      fmt.println("What is this accessor?", raw["componentType"].(f64))
      return accessor, .InvalidAccessorKind
  }

  switch raw["type"].(string) {
    case "MAT4":
      accessor.component_count = 16
    case "VEC4":
      accessor.component_count = 4
    case "VEC3":
      accessor.component_count = 3
    case "VEC2":
      accessor.component_count = 2
    case "SCALAR":
      accessor.component_count = 1
    case:
      return accessor, .InvalidAccessorKind
  }

  return accessor, nil
}

@private
parse_accessors :: proc(ctx: ^Context) -> error.Error {
  for i in 0..<len(ctx.raw_accessors) {
    ctx.accessors[i] = parse_accessor(ctx, ctx.raw_accessors[i].(json.Object)) or_return
    // log.info("ACCESSOR:", i, ctx.accessors[i].count)
  }

  return nil
}

get_accessor_size :: proc(accessor: ^Accessor) -> u32 {
  size: u32 = 0

  switch accessor.component_kind {
    case .F32: size = 4
    case .U16: size = 2
    case .U8: size = 1
  }

  return size * accessor.component_count
}
