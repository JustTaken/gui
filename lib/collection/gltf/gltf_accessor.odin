package gltf

import "base:runtime"
import "core:encoding/json"
import "core:fmt"

import "core:log"

import "lib:collection/vector"
import "lib:error"

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
  component_kind:  Accessor_Component,
  component_count: u32,
  bytes:           []u8,
  count:           u32,
  min:             vector.Vector(f32),
  max:             vector.Vector(f32),
}

@(private)
parse_accessor :: proc(
  ctx: ^Context,
  raw: json.Object,
) -> (
  accessor: Accessor,
  err: error.Error,
) {
  view := &ctx.buffer_views.data[u32(raw["bufferView"].(f64))]

  accessor.bytes = view.buffer.bytes[view.offset:view.offset + view.length]
  accessor.count = u32(raw["count"].(f64))

  switch u32(raw["componentType"].(f64)) {
  case 5126:
    accessor.component_kind = .F32
  case 5123:
    accessor.component_kind = .U16
  case 5121:
    accessor.component_kind = .U8
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

  if min, ok := raw["min"]; ok {
    array := min.(json.Array)
    accessor.min = vector.new(f32, u32(len(array)), ctx.allocator) or_return

    for i in 0 ..< len(array) {
      vector.append(&accessor.min, f32(array[i].(f64))) or_return
    }
  }

  if max, ok := raw["max"]; ok {
    array := max.(json.Array)
    assert(len(array) == int(accessor.component_count))
    accessor.max = vector.new(f32, u32(len(array)), ctx.allocator) or_return

    for i in 0 ..< len(array) {
      assert(len(array) == int(accessor.component_count))
      vector.append(&accessor.max, f32(array[i].(f64))) or_return
    }
  }

  return accessor, nil
}

@(private)
parse_accessors :: proc(ctx: ^Context) -> error.Error {
  for i in 0 ..< len(ctx.raw_accessors) {
    vector.append(
      &ctx.accessors,
      parse_accessor(ctx, ctx.raw_accessors[i].(json.Object)) or_return,
    ) or_return
  }

  return nil
}

get_accessor_size :: proc(accessor: ^Accessor) -> u32 {
  size: u32 = 0

  switch accessor.component_kind {
  case .F32:
    size = 4
  case .U16:
    size = 2
  case .U8:
    size = 1
  }

  return size * accessor.component_count
}
