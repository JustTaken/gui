#+private
package gltf

import "core:os"
import "core:path/filepath"
import "core:encoding/json"
import "./../../error"

@private
Buffer :: struct {
  bytes: []u8,
}

@private
Buffer_View :: struct {
  buffer: ^Buffer,
  length: u32,
  offset: u32,
}

@private
parse_buffer :: proc(ctx: ^Context, raw: json.Object) -> (buffer: Buffer, err: error.Error) {
  os_err: os.Error
  fd: os.Handle

  uri_array := [?]string{ctx.dir, raw["uri"].(string)}
  uri := filepath.join(uri_array[:], ctx.allocator)

  if fd, os_err = os.open(uri); os_err != nil do return buffer, .FileNotFound
  len := u32(raw["byteLength"].(f64))

  i: i64
  e: os.Error
  buffer.bytes = make([]u8, len, ctx.allocator)

  read: int
  if read, e = os.read(fd, buffer.bytes); e != nil do return buffer, .ReadFileFailed
  if read != int(len) do return buffer, .ReadFileFailed

  if os.close(fd) != nil do return buffer, .FileNotFound

  return buffer, nil
}

@private
parse_buffers :: proc(ctx: ^Context) -> error.Error {
  for i in 0 ..< len(ctx.raw_buffers) {
    ctx.buffers[i] = parse_buffer(ctx, ctx.raw_buffers[i].(json.Object)) or_return
  }

  return nil
}

@private
parse_buffer_view :: proc(ctx: ^Context, raw: json.Object) -> (view: Buffer_View, err: error.Error) {
  view.buffer = &ctx.buffers[u32(raw["buffer"].(f64))]
  view.length = u32(raw["byteLength"].(f64))
  view.offset = u32(raw["byteOffset"].(f64))

  return view, nil
}

@private
parse_buffer_views :: proc(ctx: ^Context) -> error.Error {
  for i in 0..<len(ctx.raw_buffer_views) {
    ctx.buffer_views[i] = parse_buffer_view(ctx, ctx.raw_buffer_views[i].(json.Object)) or_return
  }

  return nil
}
