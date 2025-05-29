package vulk

import "core:fmt"
import "core:sys/posix"
import vk "vendor:vulkan"
import "core:log"

import "lib:error"
import "lib:collection/vector"

Frame :: struct {
  fd: i32,
  render_pass: ^Render_Pass,
  planes: vector.Vector(vk.SubresourceLayout),
  modifier: vk.DrmFormatModifierPropertiesEXT,
  image: vk.Image,
  memory: vk.DeviceMemory,
  view: vk.ImageView,
  depth: vk.Image,
  depth_memory: vk.DeviceMemory,
  depth_view: vk.ImageView,
  buffer: vk.Framebuffer,
  width: u32,
  height: u32,
}

@private
frames_create :: proc(ctx: ^Vulkan_Context, render_pass: ^Render_Pass, count: u32, width: u32, height: u32) -> (frames: vector.Vector(Frame), err: error.Error) {
  frames = vector.new(Frame, count, ctx.allocator) or_return

  for i in 0 ..< count {
    frame := vector.one(&frames) or_return
    frame.planes = vector.new(vk.SubresourceLayout, 3, ctx.allocator) or_return
    frame.render_pass = render_pass

    frame_create(ctx, frame, width, height) or_return
  }

  return frames, nil
}

@private
frame_create :: proc(ctx: ^Vulkan_Context, frame: ^Frame, width: u32, height: u32) -> error.Error {
  frame.width = width
  frame.height = height
  frame.planes.len = 0

  modifiers := vector.new(u64, ctx.modifiers.len, ctx.tmp_allocator) or_return

  for i in 0..<ctx.modifiers.len {
    vector.append(&modifiers, ctx.modifiers.data[i].drmFormatModifier) or_return
  }

  mem_info := vk.ExternalMemoryImageCreateInfo {
    sType = .EXTERNAL_MEMORY_IMAGE_CREATE_INFO,
    handleTypes = {.DMA_BUF_EXT},
  }

  list_info := vk.ImageDrmFormatModifierListCreateInfoEXT {
    sType = .IMAGE_DRM_FORMAT_MODIFIER_LIST_CREATE_INFO_EXT,
    pNext = &mem_info,
    drmFormatModifierCount = modifiers.len,
    pDrmFormatModifiers = &modifiers.data[0],
  }

  export_info := vk.ExportMemoryAllocateInfo {
    sType = .EXPORT_MEMORY_ALLOCATE_INFO,
    pNext = nil,
    handleTypes = {.DMA_BUF_EXT},
  }

  frame.image = image_create(ctx, ctx.format, .D2, .DRM_FORMAT_MODIFIER_EXT, {.COLOR_ATTACHMENT}, {}, &list_info, width, height) or_return
  frame.memory = image_memory_create(ctx, ctx.physical_device, frame.image, {.HOST_VISIBLE, .HOST_COHERENT}, &export_info) or_return
  frame.view = image_view_create(ctx, frame.image, ctx.format, {.COLOR}) or_return

  properties := vk.ImageDrmFormatModifierPropertiesEXT {
    sType = .IMAGE_DRM_FORMAT_MODIFIER_PROPERTIES_EXT,
  }

  if vk.GetImageDrmFormatModifierPropertiesEXT(ctx.device.handle, frame.image, &properties) != .SUCCESS {
    return .GetImageModifier
  }

  for i in 0..<ctx.modifiers.len {
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

    vk.GetImageSubresourceLayout(ctx.device.handle, frame.image, &image_resource, vector.one(&frame.planes) or_return)
  }

  info := vk.MemoryGetFdInfoKHR {
    sType = .MEMORY_GET_FD_INFO_KHR,
    memory = frame.memory,
    handleType = {.DMA_BUF_EXT},
  }

  if vk.GetMemoryFdKHR(ctx.device.handle, &info, &frame.fd) != .SUCCESS {
    return .GetFdFailed
  }

  frame.depth = image_create(ctx, ctx.depth_format, .D2, .OPTIMAL, {.DEPTH_STENCIL_ATTACHMENT}, {}, nil, width, height) or_return
  frame.depth_memory = image_memory_create(ctx, ctx.physical_device, frame.depth, {.DEVICE_LOCAL}, nil ) or_return
  frame.depth_view = image_view_create(ctx, frame.depth, ctx.depth_format, {.DEPTH} ) or_return
  frame.buffer = framebuffer_create(ctx, frame.render_pass, frame.view, frame.depth_view, width, height) or_return

  return nil
}

@private
image_create :: proc(ctx: ^Vulkan_Context, format: vk.Format, type: vk.ImageType, tiling: vk.ImageTiling, usage: vk.ImageUsageFlags, flags: vk.ImageCreateFlags, pNext: rawptr, width: u32, height: u32) -> (image: vk.Image, err: error.Error) {
  info := vk.ImageCreateInfo {
    sType = .IMAGE_CREATE_INFO,
    pNext = pNext,
    flags = flags,
    imageType = type,
    format = format,
    mipLevels = 1,
    arrayLayers = 1,
    samples = {._1},
    tiling = tiling,
    usage = usage,
    sharingMode = .EXCLUSIVE,
    queueFamilyIndexCount = 0,
    pQueueFamilyIndices = nil,
    initialLayout = .UNDEFINED,
    extent = vk.Extent3D{width = width, height = height, depth = 1},
  }

  if res := vk.CreateImage(ctx.device.handle, &info, nil, &image); res != .SUCCESS {
    return image, .CreateImageFailed
  }

  return image, nil
}

@private
image_memory_create :: proc(ctx: ^Vulkan_Context, physical_device: vk.PhysicalDevice, image: vk.Image, properties: vk.MemoryPropertyFlags, pNext: rawptr) -> (memory: vk.DeviceMemory, err: error.Error) {
  requirements: vk.MemoryRequirements
  vk.GetImageMemoryRequirements(ctx.device.handle, image, &requirements)

  alloc_info := vk.MemoryAllocateInfo {
    sType = .MEMORY_ALLOCATE_INFO,
    pNext = pNext,
    allocationSize  = requirements.size,
    memoryTypeIndex = find_memory_type(
      physical_device,
      requirements.memoryTypeBits,
      properties,
    ) or_return,
  }

  if vk.AllocateMemory(ctx.device.handle, &alloc_info, nil, &memory) != .SUCCESS {
    return memory, .AllocateDeviceMemory
  }

  vk.BindImageMemory(ctx.device.handle, image, memory, vk.DeviceSize(0))

  return memory, nil
}

@private
image_view_create :: proc(ctx: ^Vulkan_Context, image: vk.Image, format: vk.Format, aspect: vk.ImageAspectFlags) -> (view: vk.ImageView, err: error.Error) {
  range := vk.ImageSubresourceRange {
    levelCount = 1,
    layerCount = 1,
    aspectMask = aspect,
    baseMipLevel = 0,
    baseArrayLayer = 0,
  }

  info := vk.ImageViewCreateInfo {
    sType = .IMAGE_VIEW_CREATE_INFO,
    image = image,
    viewType = .D2,
    format = format,
    subresourceRange = range,
  }

  if vk.CreateImageView(ctx.device.handle, &info, nil, &view) != .SUCCESS {
    return view, .CreateImageViewFailed
  }

  return view, nil
}

@private
framebuffer_create :: proc(ctx: ^Vulkan_Context, render_pass: ^Render_Pass, view: vk.ImageView, depth: vk.ImageView, width: u32, height: u32) -> (buffer: vk.Framebuffer, err: error.Error) {
  attachments := [?]vk.ImageView{view, depth}
  info := vk.FramebufferCreateInfo {
    sType = .FRAMEBUFFER_CREATE_INFO,
    renderPass = render_pass.handle,
    attachmentCount = u32(len(attachments)),
    pAttachments = &attachments[0],
    width = width,
    height = height,
    layers = 1,
  }

  if vk.CreateFramebuffer(ctx.device.handle, &info, nil, &buffer) != .SUCCESS {
    return buffer, .CreateFramebufferFailed
  }

  return buffer, nil
}

@private
frame_destroy :: proc(ctx: ^Vulkan_Context, frame: ^Frame) {
  vk.DestroyFramebuffer(ctx.device.handle, frame.buffer, nil)
  vk.DestroyImageView(ctx.device.handle, frame.view, nil)
  vk.FreeMemory(ctx.device.handle, frame.memory, nil)
  vk.DestroyImage(ctx.device.handle, frame.image, nil)
  vk.DestroyImageView(ctx.device.handle, frame.depth_view, nil)
  vk.FreeMemory(ctx.device.handle, frame.depth_memory, nil)
  vk.DestroyImage(ctx.device.handle, frame.depth, nil)

  posix.close(posix.FD(frame.fd))
}

get_frame :: proc(ctx: ^Vulkan_Context, index: u32) -> ^Frame {
  return &ctx.frames.data[index]
}

frame_resize :: proc(ctx: ^Vulkan_Context, index: u32, width: u32, height: u32) -> error.Error {
  frame := get_frame(ctx, index)

  frame_destroy(ctx, frame)
  frame_create(ctx, frame, width, height) or_return

  return nil
}

frame_draw :: proc(ctx: ^Vulkan_Context, frame_index: u32, width: u32, height: u32) -> error.Error {
  frame := get_frame(ctx, frame_index)

  submit_staging_data(ctx) or_return

  area := vk.Rect2D {
    offset = vk.Offset2D{x = 0, y = 0},
    extent = vk.Extent2D{width = width, height = height},
  }

  clear_values := [?]vk.ClearValue {
    {color = vk.ClearColorValue{float32 = {0, 0, 0, 1}}},
    {depthStencil = {1, 0}},
  }

  viewport := vk.Viewport {
    width = f32(width),
    height = f32(height),
    minDepth = 0,
    maxDepth = 1,
  }

  begin_info := vk.CommandBufferBeginInfo {
    sType = .COMMAND_BUFFER_BEGIN_INFO,
    flags = {.ONE_TIME_SUBMIT},
  }

  render_pass_info := vk.RenderPassBeginInfo {
    sType = .RENDER_PASS_BEGIN_INFO,
    renderPass = frame.render_pass.handle,
    framebuffer = frame.buffer,
    renderArea = area,
    clearValueCount = u32(len(clear_values)),
    pClearValues = &clear_values[0],
  }

  if vk.WaitForFences(ctx.device.handle, 1, &ctx.draw_fence, true, 0xFFFFFF) != .SUCCESS do return .WaitFencesFailed

  cmd := ctx.command_buffers.data[0]

  if vk.BeginCommandBuffer(cmd, &begin_info) != .SUCCESS do return .BeginCommandBufferFailed

  vk.CmdBeginRenderPass(cmd, &render_pass_info, .INLINE)
  vk.CmdSetViewport(cmd, 0, 1, &viewport)
  vk.CmdSetScissor(cmd, 0, 1, &area)

  for p in 0..<frame.render_pass.pipelines.len {
    pipeline := &frame.render_pass.pipelines.data[p]

    vk.CmdBindPipeline(cmd, .GRAPHICS, pipeline.handle)

    sets := [?]vk.DescriptorSet {
      ctx.fixed_set.handle,
      ctx.dynamic_set.handle,
    }

    vk.CmdBindDescriptorSets(cmd, .GRAPHICS, pipeline.layout.handle, 0, len(sets), &sets[0], 0, nil)

    for i in 0 ..<pipeline.groups.len {
      group := &pipeline.groups.data[i]

      if group.instances.len == 0 do continue

      offset := vk.DeviceSize(0)
      vk.CmdBindVertexBuffers(cmd, 0, 1, &group.geometry.vertex.handle, &offset)
      vk.CmdBindIndexBuffer(cmd, group.geometry.indice.handle, 0, .UINT16)
      vk.CmdDrawIndexed(cmd, group.geometry.count, group.instances.len, 0, 0, group.offset)
    }
  }

  vk.CmdEndRenderPass(cmd)

  if vk.EndCommandBuffer(cmd) != .SUCCESS do return .EndCommandBufferFailed

  wait_stage := vk.PipelineStageFlags{.COLOR_ATTACHMENT_OUTPUT}

  submit_info := vk.SubmitInfo {
    sType = .SUBMIT_INFO,
    commandBufferCount = 1,
    pCommandBuffers    = &cmd,
    pWaitDstStageMask  = &wait_stage,
  }

  vk.ResetFences(ctx.device.handle, 1, &ctx.draw_fence)
  if vk.QueueSubmit(ctx.device.queues[0].handle, 1, &submit_info, ctx.draw_fence) != .SUCCESS do return .QueueSubmitFailed

  return nil
}
