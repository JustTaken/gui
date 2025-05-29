package buffer

import "base:runtime"

import "lib:error"
import "lib:collection/vector"

Buffer :: struct {
	vec: vector.Vector(u8),
	offset: u32,
}


new :: proc(cap: u32, allocator: runtime.Allocator) -> (buffer: Buffer, err: error.Error) {
	buffer.vec = vector.new(u8, cap, allocator) or_return
	buffer.offset = 0

	return buffer, nil
}

reserve :: proc($T: typeid, buffer: ^Buffer) -> (^T, error.Error) {
  if buffer.vec.len + size_of(T) > buffer.vec.cap {
    return nil, .OutOfBounds
  }

  end := buffer.vec.len + size_of(T)
  ptr := (^T)(raw_data(buffer.vec.data[buffer.vec.len:end]))
  buffer.vec.len = end

  return ptr, nil
}

write :: proc($T: typeid, buffer: ^Buffer, item: T) -> error.Error {
  if vec.len + size_of(T) > vec.cap {
    return .OutOfBounds
  }

  end := buffer.vec.len + size_of(T)
  intrinsics.unaligned_store((^T)(raw_data(vec.data[vec.len:end])), item)
  buffer.vec.len = end

  return nil
}

read :: proc($T: typeid, buffer: ^Buffer) -> (T, error.Error) {
  value: T

  end := buffer.offset + size_of(T)

  if end > buffer.vec.len {
    return value, .OutOfBounds
  }

  value = intrinsics.unaligned_load((^T)(raw_data(buffer.vec.data[buffer.offset:end])))
  buffer.offset = end

  return value, nil
}
