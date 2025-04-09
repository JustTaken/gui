package main

import vk "vendor:vulkan"
import "core:sys/posix"

Frame :: struct {
  fd: i32,
  planes: []vk.SubresourceLayout,
  modifier: vk.DrmFormatModifierPropertiesEXT,
  image: vk.Image,
  memory: vk.DeviceMemory,
  view: vk.ImageView,
  buffer: vk.Framebuffer,
  width: u32,
  height: u32, 
}

create_frames :: proc(ctx: ^VulkanContext, count: u32, width: u32, height: u32) -> bool {
  ctx.frames = make([]Frame, count, ctx.allocator)

  for i in 0..<count {
    frame := &ctx.frames[i]
    frame.planes = make([]vk.SubresourceLayout, 3, ctx.allocator)

    create_frame(ctx, frame, width, height) or_return
  }

  return true
}

create_frame :: proc(ctx: ^VulkanContext, frame: ^Frame, width: u32, height: u32) -> bool {
  frame.width = width
  frame.height = height

  modifiers := make([]u64, len(ctx.modifiers), ctx.tmp_allocator)

  for modifier, i in ctx.modifiers {
    modifiers[i] = modifier.drmFormatModifier
  }

  mem_info := vk.ExternalMemoryImageCreateInfo {
    sType = .EXTERNAL_MEMORY_IMAGE_CREATE_INFO,
    handleTypes = { .DMA_BUF_EXT },
  }

  list_info := vk.ImageDrmFormatModifierListCreateInfoEXT {
    sType = .IMAGE_DRM_FORMAT_MODIFIER_LIST_CREATE_INFO_EXT,
    pNext = &mem_info,
    drmFormatModifierCount = u32(len(ctx.modifiers)),
    pDrmFormatModifiers = &modifiers[0],
  }

  export_info := vk.ExportMemoryAllocateInfo {
    sType = .EXPORT_MEMORY_ALLOCATE_INFO,
    pNext = nil,
    handleTypes = { .DMA_BUF_EXT },
  }

  frame.image = create_image(ctx.device, ctx.format, .D2, .DRM_FORMAT_MODIFIER_EXT, { .COLOR_ATTACHMENT }, {}, &list_info, width, height) or_return
  frame.memory = create_image_memory(ctx.device, ctx.physical_device, frame.image, &export_info) or_return
  frame.view = create_image_view(ctx.device, frame.image, ctx.format) or_return
  frame.buffer = create_framebuffer(ctx.device, ctx.render_pass, &frame.view, width, height) or_return

  properties := vk.ImageDrmFormatModifierPropertiesEXT {
    sType = .IMAGE_DRM_FORMAT_MODIFIER_PROPERTIES_EXT,
  }

  if vk.GetImageDrmFormatModifierPropertiesEXT(ctx.device, frame.image, &properties) != .SUCCESS do return false

  for modifier in ctx.modifiers {
    if modifier.drmFormatModifier == properties.drmFormatModifier {
      frame.modifier = modifier
      break
    }
  }

  for i in 0..<frame.modifier.drmFormatModifierPlaneCount {
    image_resource := vk.ImageSubresource {
      aspectMask = { PLANE_INDICES[i] },
    }

    vk.GetImageSubresourceLayout(ctx.device, frame.image, &image_resource, &frame.planes[i])
  }

  info := vk.MemoryGetFdInfoKHR {
    sType = .MEMORY_GET_FD_INFO_KHR,
    memory = frame.memory,
    handleType = { .DMA_BUF_EXT },
  }

  if vk.GetMemoryFdKHR(ctx.device, &info, &frame.fd) != .SUCCESS do return false

  return true
}

get_frame :: proc(ctx: ^VulkanContext, index: u32) -> ^Frame {
  return &ctx.frames[index]
}

resize_frame :: proc(ctx: ^VulkanContext, frame: ^Frame, width: u32, height: u32) -> bool {
  destroy_frame(ctx.device, frame)
  create_frame(ctx, frame, width, height) or_return

  return true
}

submit_staging_data :: proc(ctx: ^VulkanContext) -> bool {
  if !ctx.staging.recording do return true

  if vk.EndCommandBuffer(ctx.command_buffers[1]) != .SUCCESS do return false

  submit_info := vk.SubmitInfo {
    sType = .SUBMIT_INFO,
    commandBufferCount = 1,
    pCommandBuffers = &ctx.command_buffers[1],
  }

  vk.ResetFences(ctx.device, 1, &ctx.copy_fence)
  if vk.QueueSubmit(ctx.queues[1], 1, &submit_info, ctx.copy_fence) != .SUCCESS do return false
  if vk.WaitForFences(ctx.device, 1, &ctx.copy_fence, true, 0xFFFFFF) != .SUCCESS do return false

  ctx.staging.recording = false
  ctx.staging.len = 0

  update_descriptor_set(ctx, ctx.descriptor_sets[0], { ctx.uniform_buffer, ctx.model_buffer, ctx.color_buffer }, { 0, 1, 2 }, {.UNIFORM_BUFFER, .STORAGE_BUFFER, .STORAGE_BUFFER } , {size_of(Projection), vk.DeviceSize(size_of(InstanceModel) * ctx.max_instances), vk.DeviceSize(size_of([3]f32) * ctx.max_instances)})

  return true
}

frame_draw :: proc(ctx: ^VulkanContext, frame: ^Frame, width: u32, height: u32) -> bool {
  submit_staging_data(ctx) or_return

  cmd := ctx.command_buffers[0]

  area := vk.Rect2D {
    offset = vk.Offset2D {
      x = 0,
      y = 0,
    },

    extent = vk.Extent2D {
      width = width,
      height = height,
    }
  }

  clear_values := [?]vk.ClearValue {
    {
      color = vk.ClearColorValue {
        float32 = { 0, 0, 0, 1 },
      }
    }
  }

  viewport := vk.Viewport  {
    width = f32(width),
    height = f32(height),
    minDepth = 0,
    maxDepth = 1,
  }

  begin_info := vk.CommandBufferBeginInfo {
    sType = .COMMAND_BUFFER_BEGIN_INFO,
    flags = { .ONE_TIME_SUBMIT },
  }

  render_pass_info := vk.RenderPassBeginInfo {
    sType = .RENDER_PASS_BEGIN_INFO,
    renderPass = ctx.render_pass,
    framebuffer = frame.buffer,
    renderArea = area, 
    clearValueCount = u32(len(clear_values)),
    pClearValues = &clear_values[0],
  }

  if vk.BeginCommandBuffer(cmd, &begin_info) != .SUCCESS do return false

  vk.CmdBeginRenderPass(cmd, &render_pass_info, .INLINE)
  vk.CmdBindPipeline(cmd, .GRAPHICS, ctx.pipeline)
  vk.CmdSetViewport(cmd, 0, 1, &viewport)
  vk.CmdSetScissor(cmd, 0, 1, &area)
  vk.CmdBindDescriptorSets(cmd, .GRAPHICS, ctx.layout, 0, u32(len(ctx.descriptor_sets)), &ctx.descriptor_sets[0], 0, nil)

  for i in 0..<ctx.geometries_len {
    geometry := &ctx.geometries[i]

    if geometry.instance_count == 0 do continue

    offset := vk.DeviceSize(0)
    vk.CmdBindVertexBuffers(cmd, 0, 1, &geometry.vertex, &offset)
    vk.CmdDraw(cmd, geometry.count, geometry.instance_count, 0, geometry.instance_offset)
  }

  vk.CmdEndRenderPass(cmd)

  if vk.EndCommandBuffer(cmd) != .SUCCESS do return false

  wait_stage := vk.PipelineStageFlags { .COLOR_ATTACHMENT_OUTPUT }

  submit_info := vk.SubmitInfo {
    sType = .SUBMIT_INFO,
    commandBufferCount = 1,
    pCommandBuffers = &cmd,
    pWaitDstStageMask = &wait_stage,
  }

  if vk.WaitForFences(ctx.device, 1, &ctx.draw_fence, true, 0xFFFFFF) != .SUCCESS do return false
  vk.ResetFences(ctx.device, 1, &ctx.draw_fence)
  if vk.QueueSubmit(ctx.queues[0], 1, &submit_info, ctx.draw_fence) != .SUCCESS do return false

  return true
}

create_image :: proc(device: vk.Device, format: vk.Format, type: vk.ImageType, tiling: vk.ImageTiling, usage: vk.ImageUsageFlags, flags: vk.ImageCreateFlags, pNext: rawptr, width: u32, height: u32) -> (image: vk.Image, ok: bool) {

  info := vk.ImageCreateInfo {
    sType = .IMAGE_CREATE_INFO,
    pNext = pNext,
    flags = flags,
    imageType = type,
    format = format,
    mipLevels = 1,
    arrayLayers = 1,
    samples = { ._1 },
    tiling = tiling,
    usage = usage,
    sharingMode = .EXCLUSIVE,
    queueFamilyIndexCount = 0,
    pQueueFamilyIndices = nil,
    initialLayout = .UNDEFINED,
    extent = vk.Extent3D {
      width = width,
      height = height,
      depth = 1,
    },
  }

  if res := vk.CreateImage(device, &info, nil, &image); res != .SUCCESS {
    return image, false
  }

  return image, true
}

create_image_memory :: proc(device: vk.Device, physical_device: vk.PhysicalDevice, image: vk.Image, pNext: rawptr) -> (memory: vk.DeviceMemory, ok: bool) {
  requirements: vk.MemoryRequirements
  vk.GetImageMemoryRequirements(device, image, &requirements)

  alloc_info := vk.MemoryAllocateInfo{
    sType = .MEMORY_ALLOCATE_INFO,
    pNext = pNext,
    allocationSize = requirements.size,
    memoryTypeIndex = find_memory_type(physical_device, requirements.memoryTypeBits, { .HOST_VISIBLE, .HOST_COHERENT }) or_return
  }

  if vk.AllocateMemory(device, &alloc_info, nil, &memory) != .SUCCESS do return memory, false

  vk.BindImageMemory(device, image, memory, vk.DeviceSize(0))

  return memory, true
}

create_image_view :: proc(device: vk.Device, image: vk.Image, format: vk.Format) -> (vk.ImageView, bool) {
  components := vk.ComponentMapping {
    r = .R,
    g = .G,
    b = .B,
    a = .A,
  }

  range := vk.ImageSubresourceRange {
    levelCount = 1,
    layerCount = 1,
    aspectMask = { .COLOR },
    baseMipLevel = 0,
    baseArrayLayer = 0,
  }

  info := vk.ImageViewCreateInfo {
    sType = .IMAGE_VIEW_CREATE_INFO,
    image = image,
    viewType = .D2,
    format = format,
    components = components,
    subresourceRange = range,
  }

  view: vk.ImageView
  if vk.CreateImageView(device, &info, nil, &view) != .SUCCESS do return view, false

  return view, true
}

create_framebuffer :: proc(device: vk.Device, render_pass: vk.RenderPass, view: ^vk.ImageView, width: u32, height: u32) -> (vk.Framebuffer, bool) {
  info := vk.FramebufferCreateInfo {
    sType = .FRAMEBUFFER_CREATE_INFO,
    renderPass = render_pass,
    attachmentCount = 1,
    pAttachments = view,
    width = width,
    height = height,
    layers = 1,
  }

  buffer: vk.Framebuffer
  if vk.CreateFramebuffer(device, &info, nil, &buffer) != .SUCCESS do return buffer, false

  return buffer, true
}

destroy_frame :: proc(device: vk.Device, frame: ^Frame) {
  vk.DestroyFramebuffer(device, frame.buffer, nil)
  vk.DestroyImageView(device, frame.view, nil)
  vk.FreeMemory(device, frame.memory, nil)
  vk.DestroyImage(device, frame.image, nil)

  posix.close(posix.FD(frame.fd))
}

