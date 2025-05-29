package vector

import "base:runtime"
import "base:intrinsics"
import "core:log"
import "core:mem"

import "lib:error"

Vector :: struct(T: typeid) {
  data: [^]T,
  cap:  u32,
  len:  u32,
}

new :: proc($T: typeid, cap: u32, allocator: runtime.Allocator) -> (vec: Vector(T), err: error.Error) {
  d, e := make([]T, cap, allocator)

  if e != nil {
    log.info("Failed to allocate memory for:", typeid_of(T), cap)
    return vec, .OutOfMemory,
  }

  vec.data = raw_data(d)
  vec.cap = cap
  vec.len = 0

  return vec, nil
}

append :: proc(vec: ^Vector($T), item: T, loc := #caller_location) -> error.Error {
  if vec.len >= vec.cap {
    log.error("Failed to append element into vector of type", typeid_of(T), "len:", vec.len, "cap:", vec.cap, loc)
    return .OutOfBounds
  }

  vec.data[vec.len] = item
  vec.len += 1

  return nil
}

remove :: proc(vec: ^Vector($T), index: u32) -> error.Error {
  if index >= vec.len {
    log.error("Cannot remove elements pass the vector length")
    return .OutOfBounds
  }

  if vec.len == 0 {
    log.error("Vector does not have elements to be removed")
    return .OutOfBounds
  }

  vec.len -= 1
  vec.data[index] = vec.data[vec.len]
  return nil
}

append_n :: proc(vec: ^Vector($T), items: []T) -> error.Error {
  if vec.len + u32(len(items)) > vec.cap {
    return .OutOfBounds
  }

  end := vec.len + u32(len(items))

  copy(vec.data[vec.len:end], items)

  vec.len = end

  return nil
}

reserve_n :: proc(vec: ^Vector($T), n: u32) -> error.Error {
  if vec.len + n > vec.cap {
    log.info("Vector does not have more space", typeid_of(T), n, vec.cap, vec.len)
    return .OutOfBounds
  }

  vec.len += n

  return nil
}

one :: proc(vec: ^Vector($T)) -> (^T, error.Error) {
  if vec.len >= vec.cap {
    log.error("Failed to append element into vector len: ", vec.len, "cap:", vec.cap, "of type", typeid_of(T))
    return nil, .OutOfBounds
  }

  defer vec.len += 1

  return &vec.data[vec.len], nil
}

data :: proc(vec: ^Vector($T)) -> []T {
  return vec.data[0:vec.len]
}

offset :: proc(vec: ^Vector($T), o: u32) -> ([]T, error.Error) {
  if o > vec.len {
    log.error("Failed to get vector offset, cap:", vec.cap, "offset", o)
    return nil, .OutOfBounds
  }

  return vec.data[o:vec.len], nil
}
