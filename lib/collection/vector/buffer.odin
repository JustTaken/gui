package vector

import "base:runtime"
import "base:intrinsics"

import "lib:error"

Buffer :: struct {
	vec: Vector(u8),
	offset: u32,
}

buffer_new :: proc(cap: u32, allocator: runtime.Allocator) -> (buffer: Buffer, err: error.Error) {
	buffer.vec = new(u8, cap, allocator) or_return
	buffer.offset = 0

	return buffer, nil
}

reserve :: proc($T: typeid, buffer: ^Buffer) -> (^T, error.Error) {
  end := buffer.offset + size_of(T)

  if end > buffer.vec.cap {
    return nil, .OutOfBounds
  }

  ptr := (^T)(raw_data(buffer.vec.data[buffer.offset:end]))
  buffer.offset = end

  return ptr, nil
}

write :: proc($T: typeid, buffer: ^Buffer, item: T) -> error.Error {
  end := buffer.offset + size_of(T)

  if end > buffer.vec.cap {
    return .OutOfBounds
  }

  intrinsics.unaligned_store((^T)(raw_data(buffer.vec.data[buffer.offset:end])), item)
  buffer.offset = end

  return nil
}

write_n :: proc($T: typeid, buffer: ^Buffer, data: []T) -> error.Error {
  for d in data {
  	write(T, buffer, d) or_return
  }

  return nil
}

padd_n :: proc(buffer: ^Buffer, n: u32) -> error.Error {
  if buffer.offset + n > buffer.vec.cap {
    return .OutOfBounds
  }

  buffer.offset += n

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

read_n :: proc(buffer: ^Buffer, count: u32) -> ([]u8, error.Error ) {
  if buffer.offset + count > buffer.vec.len {
    return nil, .OutOfBounds
  }

  bytes := buffer.vec.data[buffer.offset:buffer.offset + count]
  buffer.offset += count

  return bytes, nil
}

reader_reset :: proc(buffer: ^Buffer, cap: u32) {
	buffer.vec.len = cap
	buffer.offset = 0
}

