#+private
package collection

import "core:os"
import "./../error"

Gltf_Buffer :: struct {
  fd:  os.Handle,
  len: u32,
}

read_from_buffer :: proc(ctx: ^Gltf_Context, buffer: Gltf_Buffer, length: u32, offset: u32) -> (bytes: []u8, err: error.Error) {
  i: i64
  e: os.Error
  bytes = make([]u8, length, ctx.tmp_allocator)

  if i, e = os.seek(buffer.fd, i64(offset), os.SEEK_SET); e != nil do return bytes, .FileNotFound

  read: int
  if read, e = os.read(buffer.fd, bytes); e != nil do return bytes, .ReadFileFailed
  if read != int(length) do return bytes, .ReadFileFailed

  return bytes, nil
}

