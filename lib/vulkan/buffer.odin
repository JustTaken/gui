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
buffer_create :: proc(
  buffer: ^Buffer,
  ctx: ^Vulkan_Context,
  size: u32,
  usage: vk.BufferUsageFlags,
  properties: vk.MemoryPropertyFlags,
) -> error.Error {
  buf_info := vk.BufferCreateInfo {
    sType       = .BUFFER_CREATE_INFO,
    size        = vk.DeviceSize(size),
    usage       = usage,
    flags       = {},
    sharingMode = .EXCLUSIVE,
  }

  if vk.CreateBuffer(ctx.device.handle, &buf_info, nil, &buffer.handle) !=
     .SUCCESS {
    return .CreateBuffer
  }

  requirements: vk.MemoryRequirements
  vk.GetBufferMemoryRequirements(
    ctx.device.handle,
    buffer.handle,
    &requirements,
  )

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

  if vk.AllocateMemory(ctx.device.handle, &alloc_info, nil, &buffer.memory) !=
     .SUCCESS {
    return .AllocateDeviceMemory
  }

  vk.BindBufferMemory(ctx.device.handle, buffer.handle, buffer.memory, 0)

  buffer.len = 0
  buffer.cap = u32(size)

  return nil
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
buffer_append :: proc(
  $T: typeid,
  ctx: ^Vulkan_Context,
  buffer: ^Buffer,
  data: []T,
) -> (
  offset: u32,
  err: error.Error,
) {
  offset = buffer.len

  memory_copy(T, ctx, buffer.memory, buffer.len, data)
  buffer.len += u32(len(data) * size_of(T))

  return offset, nil
}

@(private)
copy_data_to_image :: proc(
  ctx: ^Vulkan_Context,
  data: []u8,
  image: ^Image,
  width: u32,
  height: u32,
  aspect: vk.ImageAspectFlags,
) -> error.Error {
  l := u32(len(data))

  buffer_check_cap(ctx, l) or_return

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

  staging_offset := buffer_append(u8, ctx, ctx.staging, data) or_return
  copy_info := vk.BufferImageCopy {
    bufferOffset      = vk.DeviceSize(staging_offset),
    bufferRowLength   = 0,
    bufferImageHeight = 0,
    imageSubresource  = resource,
    imageOffset       = offset,
    imageExtent       = extent,
  }

  vk.CmdCopyBufferToImage(
    ctx.transfer_command_buffer.handle,
    ctx.staging.handle,
    image.handle,
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

  buffer_check_cap(ctx, l) or_return

  if dst_offset >= dst_buffer.cap {
    log.error("Trying to copy data outside of buffer boundary")
    return .OutOfBounds
  }

  staging_offset := buffer_append(T, ctx, ctx.staging, data) or_return

  copy_info := vk.BufferCopy {
    srcOffset = vk.DeviceSize(staging_offset),
    dstOffset = vk.DeviceSize(dst_offset * size_of(T)),
    size      = vk.DeviceSize(l * size_of(T)),
  }

  vk.CmdCopyBuffer(
    ctx.transfer_command_buffer.handle,
    ctx.staging.handle,
    dst_buffer.handle,
    1,
    &copy_info,
  )

  return nil
}

@(private)
buffer_check_cap :: proc(ctx: ^Vulkan_Context, l: u32) -> error.Error {
  if ctx.staging.len + l > ctx.staging.cap {
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
buffer_destroy :: proc(ctx: ^Vulkan_Context, buffer: ^Buffer) {
  vk.DestroyBuffer(ctx.device.handle, buffer.handle, nil)
  vk.FreeMemory(ctx.device.handle, buffer.memory, nil)
}
