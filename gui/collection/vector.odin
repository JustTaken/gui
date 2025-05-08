package collection

import "base:runtime"
import "base:intrinsics"
import "core:mem"

import "./../error"

Vector :: struct(T: typeid) {
  data: []T,
  cap:  u32,
  len:  u32,
}

new_vec :: proc($T: typeid, cap: u32, allocator: runtime.Allocator) -> (Vector(T), error.Error) {
  e: mem.Allocator_Error
  vec: Vector(T)
  vec.data, e = make([]T, cap, allocator)
  vec.cap = cap
  vec.len = 0

  if e != nil {
    return vec, .OutOfMemory,
  }

  return vec, nil
}

vec_append :: proc(vec: ^Vector($T), item: T) -> error.Error {
  if vec.len >= vec.cap {
    return .OutOfBounds
  }

  vec.data[vec.len] = item
  vec.len += 1

  return nil
}

vec_append_n :: proc(vec: ^Vector($T), items: []T) -> error.Error {
  if vec.len + u32(len(items)) > vec.cap {
    return .OutOfBounds
  }

  defer vec.len += u32(len(items))

  copy(vec.data[vec.len:], items)

  return nil
}

vec_add_n :: proc(vec: ^Vector($T), count: u32) -> error.Error {
  if vec.len + count > vec.cap {
    return .OutOfBounds
  }

  vec.len += count

  return nil
}

vec_read :: proc(vec: ^Vector(u8), $T: typeid) -> (T, error.Error) {
  value: T

  if vec.len + size_of(T) > vec.cap {
    return value, .OutOfBounds
  }

  defer vec.len += size_of(T)
  value = intrinsics.unaligned_load((^T)(raw_data(vec.data[vec.len:])))

  return value, nil
}

vec_read_n :: proc(vec: ^Vector(u8), count: u32) -> ([]u8, error.Error ) {
  if vec.len + count > vec.cap {
    return nil, .OutOfBounds
  }

  defer vec.len += count

  return vec.data[vec.len:vec.len + count], nil
}

vec_append_generic :: proc(vec: ^Vector(u8), $T: typeid, item: T) -> error.Error {
  if vec.len + size_of(T) > vec.cap {
    return .OutOfBounds
  }

  defer vec.len += size_of(T)
  intrinsics.unaligned_store((^T)(raw_data(vec.data[vec.len:])), item)

  return nil
}

vec_reserve :: proc(vec: ^Vector(u8), $T: typeid) -> (^T, error.Error) {
  if vec.len + size_of(T) > vec.cap {
    return nil, .OutOfBounds
  }

  defer vec.len += size_of(T)

  return (^T)(raw_data(vec.data[vec.len:])), nil
}

