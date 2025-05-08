package wayland

import vk "./../vulkan"
import "./../error"

Buffer :: struct {
  data:     []u8,
  id:       u32,
  offset:   u32,
  width:    u32,
  height:   u32,
  released: bool,
  bound:    bool,
  frame:    ^vk.Frame,
  next:     ^Buffer,
}

wayland_buffer_write_swap :: proc(ctx: ^Wayland_Context, buffer: ^Buffer, width: u32, height: u32) -> error.Error {
  if !buffer.released {
    return .BufferNotReleased
  }

  defer buffer.released = false

  if buffer.width != width || buffer.height != height {
    if buffer.bound do write(ctx, {}, buffer.id, ctx.destroy_buffer_opcode)

    vk.resize_frame(ctx.vk, buffer.frame, width, height) or_return
    wayland_buffer_create(ctx, buffer, width, height)
  }

  vk.frame_draw(ctx.vk, buffer.frame, width, height) or_return

  write(ctx, {Object(buffer.id), Int(0), Int(0)}, ctx.surface_id, ctx.surface_attach_opcode)
  write(
    ctx,
    {Int(0), Int(0), Int(width), Int(height)},
    ctx.surface_id,
    ctx.surface_damage_opcode,
  )
  write(ctx, {}, ctx.surface_id, ctx.surface_commit_opcode)

  ctx.buffer = buffer.next

  return nil
}

wayland_buffers_init :: proc(ctx: ^Wayland_Context) {
  ctx.buffers[0].id = ctx.buffer_base_id
  for i in 0 ..< len(ctx.buffers) {
    buffer := &ctx.buffers[i]

    if i != 0 do buffer.id = copy_id(ctx, ctx.buffer.id)

    buffer.frame = vk.get_frame(ctx.vk, buffer.id - ctx.buffer_base_id)
    buffer.released = true
    buffer.bound = false
    buffer.width = 0
    buffer.height = 0
  }
}

wayland_buffer_create :: proc(ctx: ^Wayland_Context, buffer: ^Buffer, width: u32, height: u32) {
  buffer.bound = true

  write(ctx, {BoundNewId(ctx.dma_params_id)}, ctx.dma_id, ctx.dma_create_param_opcode)

  for i in 0 ..< buffer.frame.modifier.drmFormatModifierPlaneCount {
    plane := &buffer.frame.planes[i]
    modifier_hi := (buffer.frame.modifier.drmFormatModifier & 0xFFFFFFFF00000000) >> 32
    modifier_lo := buffer.frame.modifier.drmFormatModifier & 0x00000000FFFFFFFF

    write(
      ctx,
      {
        Fd(buffer.frame.fd),
        Uint(i),
        Uint(plane.offset),
        Uint(plane.rowPitch),
        Uint(modifier_hi),
        Uint(modifier_lo),
      },
      ctx.dma_params_id,
      ctx.dma_params_add_opcode,
    )
  }

  buffer.width = width
  buffer.height = height

  format := vk.drm_format(ctx.vk.format)

  write(
    ctx,
    {BoundNewId(buffer.id), Int(width), Int(height), Uint(format), Uint(0)},
    ctx.dma_params_id,
    ctx.dma_params_create_immed_opcode,
  )
  write(ctx, {}, ctx.dma_params_id, ctx.dma_params_destroy_opcode)
}
