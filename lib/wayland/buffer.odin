package wayland

import "lib:collection/vector"
import "lib:error"
import "lib:vulkan"
import "lib:wayland/interface"

@(private)
Buffer :: struct {
  id:       u32,
  offset:   u32,
  width:    u32,
  height:   u32,
  released: bool,
  bound:    bool,
}

@(private)
buffers_init :: proc(ctx: ^Wayland_Context) -> error.Error {
  ctx.ids.buffer_base = get_id(
    ctx,
    "wl_buffer",
    {new_callback("release", buffer_release_callback)},
    interface.WAYLAND_INTERFACES[:],
  ) or_return

  ctx.opcodes.destroy_buffer = get_request_opcode(
    ctx,
    "destroy",
    ctx.ids.buffer_base,
  ) or_return

  vector.append(&ctx.buffers, Buffer{id = ctx.ids.buffer_base}) or_return

  for i in 1 ..< ctx.buffers.cap {
    vector.append(
      &ctx.buffers,
      Buffer{id = copy_id(ctx, ctx.ids.buffer_base) or_return},
    ) or_return
  }

  for i in 0 ..< ctx.buffers.cap {
    ctx.buffers.data[i].released = true
    ctx.buffers.data[i].bound = false
    ctx.buffers.data[i].width = 0
    ctx.buffers.data[i].height = 0
  }

  return nil
}

@(private)
buffer_write_swap :: proc(
  ctx: ^Wayland_Context,
  width: u32,
  height: u32,
) -> error.Error {
  buffer := &ctx.buffers.data[ctx.active_buffer]

  if !buffer.released {
    return .BufferNotReleased
  }

  defer buffer.released = false

  if buffer.width != width || buffer.height != height {
    if buffer.bound do write(ctx, {}, buffer.id, ctx.opcodes.destroy_buffer)

    vulkan.frame_resize(ctx.vk, ctx.active_buffer, width, height) or_return
    buffer_create(ctx, ctx.active_buffer, width, height)
  }

  vulkan.frame_draw(ctx.vk, ctx.active_buffer, width, height) or_return

  write(
    ctx,
    {interface.Object(buffer.id), interface.Int(0), interface.Int(0)},
    ctx.ids.surface,
    ctx.opcodes.surface_attach,
  )

  write(
    ctx,
    {
      interface.Int(0),
      interface.Int(0),
      interface.Int(width),
      interface.Int(height),
    },
    ctx.ids.surface,
    ctx.opcodes.surface_damage,
  )

  write(ctx, {}, ctx.ids.surface, ctx.opcodes.surface_commit)

  ctx.active_buffer = (ctx.active_buffer + 1) % ctx.buffers.len

  return nil
}

@(private)
buffer_create :: proc(
  ctx: ^Wayland_Context,
  index: u32,
  width: u32,
  height: u32,
) -> error.Error {
  buffer := &ctx.buffers.data[index]
  buffer.bound = true

  write(
    ctx,
    {interface.BoundNewId(ctx.ids.dma_params)},
    ctx.ids.dma,
    ctx.opcodes.dma_create_param,
  ) or_return

  frame := vulkan.get_frame(ctx.vk, index)

  for i in 0 ..< frame.modifier.drmFormatModifierPlaneCount {
    plane := &frame.planes.data[i]
    modifier_hi :=
      (frame.modifier.drmFormatModifier & 0xFFFFFFFF00000000) >> 32
    modifier_lo := frame.modifier.drmFormatModifier & 0x00000000FFFFFFFF

    write(
      ctx,
      {
        interface.Fd(frame.fd),
        interface.Uint(i),
        interface.Uint(plane.offset),
        interface.Uint(plane.rowPitch),
        interface.Uint(modifier_hi),
        interface.Uint(modifier_lo),
      },
      ctx.ids.dma_params,
      ctx.opcodes.dma_params_add,
    ) or_return
  }

  buffer.width = width
  buffer.height = height

  format := vulkan.drm_format(ctx.vk.format)

  write(
    ctx,
    {
      interface.BoundNewId(buffer.id),
      interface.Int(width),
      interface.Int(height),
      interface.Uint(format),
      interface.Uint(0),
    },
    ctx.ids.dma_params,
    ctx.opcodes.dma_params_create_immed,
  ) or_return

  write(ctx, {}, ctx.ids.dma_params, ctx.opcodes.dma_params_destroy) or_return

  return nil
}
