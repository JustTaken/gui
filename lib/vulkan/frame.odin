package vulk

import "core:fmt"
import "core:log"
import "core:sys/posix"
import vk "vendor:vulkan"

import "lib:collection/vector"
import "lib:error"

Frame :: struct {
  fd:          i32,
  render_pass: ^Render_Pass,
  planes:      vector.Vector(vk.SubresourceLayout),
  modifier:    vk.DrmFormatModifierPropertiesEXT,
  image:       Image,
  depth:       Image,
  buffer:      vk.Framebuffer,
  width:       u32,
  height:      u32,
}

@(private)
frames_create :: proc(
  ctx: ^Vulkan_Context,
  render_pass: ^Render_Pass,
  count: u32,
  width: u32,
  height: u32,
) -> (
  frames: vector.Vector(Frame),
  err: error.Error,
) {
  frames = vector.new(Frame, count, ctx.allocator) or_return

  for i in 0 ..< count {
    frame := vector.one(&frames) or_return
    frame.planes = vector.new(vk.SubresourceLayout, 3, ctx.allocator) or_return
    frame.render_pass = render_pass

    frame_create(ctx, frame, width, height) or_return
  }

  return frames, nil
}

@(private)
frame_create :: proc(
  ctx: ^Vulkan_Context,
  frame: ^Frame,
  width: u32,
  height: u32,
) -> error.Error {
  frame.width = width
  frame.height = height
  frame.planes.len = 0

  modifiers := vector.new(u64, ctx.modifiers.len, ctx.tmp_allocator) or_return

  for i in 0 ..< ctx.modifiers.len {
    vector.append(
      &modifiers,
      ctx.modifiers.data[i].drmFormatModifier,
    ) or_return
  }

  mem_info := vk.ExternalMemoryImageCreateInfo {
    sType       = .EXTERNAL_MEMORY_IMAGE_CREATE_INFO,
    handleTypes = {.DMA_BUF_EXT},
  }

  list_info := vk.ImageDrmFormatModifierListCreateInfoEXT {
    sType                  = .IMAGE_DRM_FORMAT_MODIFIER_LIST_CREATE_INFO_EXT,
    pNext                  = &mem_info,
    drmFormatModifierCount = modifiers.len,
    pDrmFormatModifiers    = &modifiers.data[0],
  }

  export_info := vk.ExportMemoryAllocateInfo {
    sType       = .EXPORT_MEMORY_ALLOCATE_INFO,
    pNext       = nil,
    handleTypes = {.DMA_BUF_EXT},
  }

  frame.image = image_create(
    ctx,
    width = width,
    height = height,
    format = ctx.format,
    type = .D2,
    tiling = .DRM_FORMAT_MODIFIER_EXT,
    usage = {.COLOR_ATTACHMENT},
    properties = {.HOST_VISIBLE, .HOST_COHERENT},
    aspect = vk.ImageAspectFlags{.COLOR},
    image_pNext = &list_info,
    memory_pNext = &export_info,
  ) or_return

  properties := vk.ImageDrmFormatModifierPropertiesEXT {
    sType = .IMAGE_DRM_FORMAT_MODIFIER_PROPERTIES_EXT,
  }

  if vk.GetImageDrmFormatModifierPropertiesEXT(
       ctx.device.handle,
       frame.image.handle,
       &properties,
     ) !=
     .SUCCESS {
    return .GetImageModifier
  }

  for i in 0 ..< ctx.modifiers.len {
    modifier := ctx.modifiers.data[i]

    if modifier.drmFormatModifier == properties.drmFormatModifier {
      frame.modifier = modifier

      break
    }
  }

  for i in 0 ..< frame.modifier.drmFormatModifierPlaneCount {
    image_resource := vk.ImageSubresource {
      aspectMask = {PLANE_INDICES[i]},
    }

    vk.GetImageSubresourceLayout(
      ctx.device.handle,
      frame.image.handle,
      &image_resource,
      vector.one(&frame.planes) or_return,
    )
  }

  info := vk.MemoryGetFdInfoKHR {
    sType      = .MEMORY_GET_FD_INFO_KHR,
    memory     = frame.image.memory,
    handleType = {.DMA_BUF_EXT},
  }

  if vk.GetMemoryFdKHR(ctx.device.handle, &info, &frame.fd) != .SUCCESS {
    return .GetFdFailed
  }

  frame.depth = image_create(
    ctx,
    width = width,
    height = height,
    format = ctx.depth_format,
    type = .D2,
    tiling = .OPTIMAL,
    usage = {.DEPTH_STENCIL_ATTACHMENT},
    properties = {.DEVICE_LOCAL},
    aspect = vk.ImageAspectFlags{.DEPTH},
  ) or_return

  frame.buffer = framebuffer_create(
    ctx,
    frame.render_pass,
    frame.image.view.?,
    frame.depth.view.?,
    width,
    height,
  ) or_return

  return nil
}

@(private)
framebuffer_create :: proc(
  ctx: ^Vulkan_Context,
  render_pass: ^Render_Pass,
  view: vk.ImageView,
  depth: vk.ImageView,
  width: u32,
  height: u32,
) -> (
  buffer: vk.Framebuffer,
  err: error.Error,
) {
  attachments := [?]vk.ImageView{view, depth}

  info := vk.FramebufferCreateInfo {
    sType           = .FRAMEBUFFER_CREATE_INFO,
    renderPass      = render_pass.handle,
    attachmentCount = u32(len(attachments)),
    pAttachments    = &attachments[0],
    width           = width,
    height          = height,
    layers          = 1,
  }

  if vk.CreateFramebuffer(ctx.device.handle, &info, nil, &buffer) != .SUCCESS {
    return buffer, .CreateFramebufferFailed
  }

  return buffer, nil
}

get_frame :: proc(ctx: ^Vulkan_Context, index: u32) -> ^Frame {
  return &ctx.frames.data[index]
}

frame_resize :: proc(
  ctx: ^Vulkan_Context,
  index: u32,
  width: u32,
  height: u32,
) -> error.Error {
  frame := get_frame(ctx, index)

  frame_destroy(ctx, frame)
  frame_create(ctx, frame, width, height) or_return

  return nil
}

frame_draw :: proc(
  ctx: ^Vulkan_Context,
  frame_index: u32,
  width: u32,
  height: u32,
) -> error.Error {
  command_buffer_end(
    ctx,
    ctx.transfer_command_buffer,
    ctx.copy_fence,
  ) or_return

  ctx.staging.buffer.len = 0

  for i in 0 ..< ctx.descriptor_pool.sets.len {
    descriptor_set_update(ctx, ctx.descriptor_pool.sets.data[i])
  }

  frame := get_frame(ctx, frame_index)

  area := vk.Rect2D {
    offset = vk.Offset2D{x = 0, y = 0},
    extent = vk.Extent2D{width = width, height = height},
  }

  clear_values := [?]vk.ClearValue {
    {color = vk.ClearColorValue{float32 = {0, 0, 0, 1}}},
    {depthStencil = {1, 0}},
  }

  viewport := vk.Viewport {
    width    = f32(width),
    height   = f32(height),
    minDepth = 0,
    maxDepth = 1,
  }

  begin_info := vk.CommandBufferBeginInfo {
    sType = .COMMAND_BUFFER_BEGIN_INFO,
    flags = {.ONE_TIME_SUBMIT},
  }

  render_pass_info := vk.RenderPassBeginInfo {
    sType           = .RENDER_PASS_BEGIN_INFO,
    renderPass      = frame.render_pass.handle,
    framebuffer     = frame.buffer,
    renderArea      = area,
    clearValueCount = u32(len(clear_values)),
    pClearValues    = &clear_values[0],
  }

  if vk.WaitForFences(ctx.device.handle, 1, &ctx.draw_fence, true, 0xFFFFFF) != .SUCCESS do return .WaitFencesFailed

  cmd := ctx.draw_command_buffer

  if vk.BeginCommandBuffer(cmd.handle, &begin_info) != .SUCCESS do return .BeginCommandBufferFailed

  vk.CmdBeginRenderPass(cmd.handle, &render_pass_info, .INLINE)
  vk.CmdSetViewport(cmd.handle, 0, 1, &viewport)
  vk.CmdSetScissor(cmd.handle, 0, 1, &area)

  for p in 0 ..< frame.render_pass.pipelines.len {
    pipeline := &frame.render_pass.pipelines.data[p]

    vk.CmdBindPipeline(cmd.handle, .GRAPHICS, pipeline.handle)

    sets := [?]vk.DescriptorSet{ctx.fixed_set.handle, ctx.dynamic_set.handle}

    vk.CmdBindDescriptorSets(
      cmd.handle,
      .GRAPHICS,
      pipeline.layout.handle,
      0,
      len(sets),
      &sets[0],
      0,
      nil,
    )

    for i in 0 ..< pipeline.groups.len {
      group := &pipeline.groups.data[i]

      if group.instances.len == 0 do continue

      offset := vk.DeviceSize(0)

      vk.CmdBindIndexBuffer(
        cmd.handle,
        group.geometry.indice.handle,
        0,
        .UINT16,
      )

      vk.CmdBindVertexBuffers(
        cmd.handle,
        0,
        1,
        &group.geometry.vertex.handle,
        &offset,
      )

      vk.CmdDrawIndexed(
        cmd.handle,
        group.geometry.count,
        group.instances.len,
        0,
        0,
        group.offset,
      )
    }
  }

  vk.CmdEndRenderPass(cmd.handle)

  if vk.EndCommandBuffer(cmd.handle) != .SUCCESS do return .EndCommandBufferFailed

  wait_stage := vk.PipelineStageFlags{.COLOR_ATTACHMENT_OUTPUT}

  submit_info := vk.SubmitInfo {
    sType              = .SUBMIT_INFO,
    commandBufferCount = 1,
    pCommandBuffers    = &cmd.handle,
    pWaitDstStageMask  = &wait_stage,
  }

  vk.ResetFences(ctx.device.handle, 1, &ctx.draw_fence)

  render_pass_destroy_unused(ctx, frame.render_pass)

  if vk.QueueSubmit(cmd.pool.queue.handle, 1, &submit_info, ctx.draw_fence) != .SUCCESS do return .QueueSubmitFailed

  command_buffer_begin(ctx, ctx.transfer_command_buffer) or_return

  return nil
}

@(private)
frame_destroy :: proc(ctx: ^Vulkan_Context, frame: ^Frame) {
  vk.DestroyFramebuffer(ctx.device.handle, frame.buffer, nil)
  vk.DestroyImageView(ctx.device.handle, frame.image.view.?, nil)
  vk.FreeMemory(ctx.device.handle, frame.image.memory, nil)
  vk.DestroyImage(ctx.device.handle, frame.image.handle, nil)
  vk.DestroyImageView(ctx.device.handle, frame.depth.view.?, nil)
  vk.FreeMemory(ctx.device.handle, frame.depth.memory, nil)
  vk.DestroyImage(ctx.device.handle, frame.depth.handle, nil)

  posix.close(posix.FD(frame.fd))
}
