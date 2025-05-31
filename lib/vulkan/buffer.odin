package vulk

import "core:log"
import "lib:error"
import vk "vendor:vulkan"

@(private)
Buffer :: struct {
  handle: vk.Buffer,
  memory: vk.DeviceMemory,
  len:    u32,
  cap:    u32,
}

@(private)
StagingBuffer :: struct {
  buffer:    Buffer,
  recording: bool,
}

@(private)
buffer_create :: proc(
  ctx: ^Vulkan_Context,
  size: u32,
  usage: vk.BufferUsageFlags,
  properties: vk.MemoryPropertyFlags,
) -> (
  buffer: Buffer,
  err: error.Error,
) {
  buffer.handle = vulkan_buffer_create(ctx, size, usage) or_return
  buffer.memory = buffer_create_memory(
    ctx,
    buffer.handle,
    properties,
  ) or_return

  buffer.len = 0
  buffer.cap = u32(size)

  return buffer, nil
}

@(private)
vulkan_buffer_create :: proc(
  ctx: ^Vulkan_Context,
  size: u32,
  usage: vk.BufferUsageFlags,
) -> (
  buffer: vk.Buffer,
  err: error.Error,
) {
  buf_info := vk.BufferCreateInfo {
    sType       = .BUFFER_CREATE_INFO,
    size        = vk.DeviceSize(size),
    usage       = usage,
    flags       = {},
    sharingMode = .EXCLUSIVE,
  }

  if vk.CreateBuffer(ctx.device.handle, &buf_info, nil, &buffer) != .SUCCESS {
    return buffer, .CreateBuffer
  }

  return buffer, nil
}

@(private)
buffer_create_memory :: proc(
  ctx: ^Vulkan_Context,
  buffer: vk.Buffer,
  properties: vk.MemoryPropertyFlags,
) -> (
  memory: vk.DeviceMemory,
  err: error.Error,
) {
  requirements: vk.MemoryRequirements
  vk.GetBufferMemoryRequirements(ctx.device.handle, buffer, &requirements)

  alloc_info := vk.MemoryAllocateInfo {
    sType           = .MEMORY_ALLOCATE_INFO,
    pNext           = nil,
    allocationSize  = requirements.size,
    memoryTypeIndex = find_memory_type(
      ctx,
      requirements.memoryTypeBits,
      properties,
    ) or_return,
  }

  if vk.AllocateMemory(ctx.device.handle, &alloc_info, nil, &memory) !=
     .SUCCESS {
    return memory, .AllocateDeviceMemory
  }

  vk.BindBufferMemory(ctx.device.handle, buffer, memory, 0)

  return memory, nil
}

@(private)
memory_copy :: proc(
  $T: typeid,
  ctx: ^Vulkan_Context,
  memory: vk.DeviceMemory,
  offset: u32,
  data: []T,
) {
  l := len(data)

  out: [^]T
  vk.MapMemory(
    ctx.device.handle,
    memory,
    vk.DeviceSize(offset),
    vk.DeviceSize(l * size_of(T)),
    {},
    (^rawptr)(&out),
  )
  copy(out[0:l], data)
  vk.UnmapMemory(ctx.device.handle, memory)
}

@(private)
staging_buffer_append :: proc(
  $T: typeid,
  ctx: ^Vulkan_Context,
  data: []T,
) -> (
  offset: u32,
  err: error.Error,
) {
  offset = ctx.staging.buffer.len

  memory_copy(T, ctx, ctx.staging.buffer.memory, ctx.staging.buffer.len, data)
  ctx.staging.buffer.len += u32(len(data) * size_of(T))

  return offset, nil
}

@(private)
copy_data_to_image :: proc(
  ctx: ^Vulkan_Context,
  data: []u8,
  image: vk.Image,
  aspect: vk.ImageAspectFlags,
  width: u32,
  height: u32,
) -> error.Error {
  l := u32(len(data))

  staging_buffer_check_cap(ctx, l) or_return

  if ctx.staging.buffer.len + l > ctx.staging.buffer.cap {
    return .OutOfStagingMemory
  }

  resource := vk.ImageSubresourceLayers {
    aspectMask     = aspect,
    mipLevel       = 0,
    baseArrayLayer = 0,
    layerCount     = 1,
  }

  extent := vk.Extent3D {
    width  = width,
    height = height,
    depth  = 1,
  }

  offset := vk.Offset3D {
    x = 0,
    y = 0,
    z = 0,
  }

  copy_info := vk.BufferImageCopy {
    bufferOffset      = 0,
    bufferRowLength   = 0,
    bufferImageHeight = 0,
    imageSubresource  = resource,
    imageOffset       = offset,
    imageExtent       = extent,
  }

  vk.CmdCopyBufferToImage(
    ctx.transfer_command_buffer.handle,
    ctx.staging.buffer.handle,
    image,
    .TRANSFER_DST_OPTIMAL,
    1,
    &copy_info,
  )

  return nil
}

@(private)
copy_data_to_buffer :: proc(
  $T: typeid,
  ctx: ^Vulkan_Context,
  data: []T,
  dst_buffer: ^Buffer,
  dst_offset: u32,
) -> error.Error {
  l := u32(len(data))

  staging_buffer_check_cap(ctx, l) or_return

  if dst_offset >= dst_buffer.cap {
    log.error("Trying to copy data outside of buffer boundary")
    return .OutOfBounds
  }

  staging_offset := staging_buffer_append(T, ctx, data) or_return

  copy_info := vk.BufferCopy {
    srcOffset = vk.DeviceSize(staging_offset),
    dstOffset = vk.DeviceSize(dst_offset * size_of(T)),
    size      = vk.DeviceSize(l * size_of(T)),
  }

  vk.CmdCopyBuffer(
    ctx.transfer_command_buffer.handle,
    ctx.staging.buffer.handle,
    dst_buffer.handle,
    1,
    &copy_info,
  )

  return nil
}

@(private)
staging_buffer_check_cap :: proc(ctx: ^Vulkan_Context, l: u32) -> error.Error {
  if ctx.staging.buffer.len + l > ctx.staging.buffer.cap {
    return .OutOfStagingMemory
  }

  return nil
}

@(private)
find_memory_type :: proc(
  ctx: ^Vulkan_Context,
  type_filter: u32,
  properties: vk.MemoryPropertyFlags,
) -> (
  u32,
  error.Error,
) {
  mem_properties: vk.PhysicalDeviceMemoryProperties
  vk.GetPhysicalDeviceMemoryProperties(ctx.physical_device, &mem_properties)

  for i in 0 ..< mem_properties.memoryTypeCount {
    if (type_filter & (1 << i) != 0) && (mem_properties.memoryTypes[i].propertyFlags & properties) == properties do return i, nil
  }

  return 0, .MemoryNotFound
}

@(private)
buffer_destroy :: proc(ctx: ^Vulkan_Context, buffer: Buffer) {
  vk.DestroyBuffer(ctx.device.handle, buffer.handle, nil)
  vk.FreeMemory(ctx.device.handle, buffer.memory, nil)
}
