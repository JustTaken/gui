package vulk

import vk "vendor:vulkan"
import "core:log"
import "./../error"

@private
Buffer :: struct {
  handle: vk.Buffer,
  memory: vk.DeviceMemory,
  len: u32,
  cap: u32,
}

@private
StagingBuffer :: struct {
  buffer: Buffer,
  recording: bool,
}

@private
buffer_create :: proc(ctx: ^Vulkan_Context, size: u32, usage: vk.BufferUsageFlags, properties: vk.MemoryPropertyFlags) -> (buffer: Buffer, err: error.Error) {
  buffer.handle = vulkan_buffer_create(ctx, size, usage) or_return
  buffer.memory = buffer_create_memory(ctx, buffer.handle, properties) or_return

  buffer.len = 0
  buffer.cap = u32(size)

  return buffer, nil
}

@private
vulkan_buffer_create :: proc(ctx: ^Vulkan_Context, size: u32, usage: vk.BufferUsageFlags) -> (vk.Buffer, error.Error) {
  buf_info := vk.BufferCreateInfo {
    sType       = .BUFFER_CREATE_INFO,
    pNext       = nil,
    size        = vk.DeviceSize(size),
    usage       = usage,
    flags       = {},
    sharingMode = .EXCLUSIVE,
  }

  buffer: vk.Buffer
  if vk.CreateBuffer(ctx.device.handle, &buf_info, nil, &buffer) != .SUCCESS do return buffer, .CreateBuffer

  return buffer, nil
}

@private
buffer_create_memory :: proc(ctx: ^Vulkan_Context, buffer: vk.Buffer, properties: vk.MemoryPropertyFlags) -> (memory: vk.DeviceMemory, err: error.Error) {
  requirements: vk.MemoryRequirements
  vk.GetBufferMemoryRequirements(ctx.device.handle, buffer, &requirements)

  alloc_info := vk.MemoryAllocateInfo {
    sType     = .MEMORY_ALLOCATE_INFO,
    pNext     = nil,
    allocationSize  = requirements.size,
    memoryTypeIndex = find_memory_type(
      ctx.physical_device,
      requirements.memoryTypeBits,
      properties,
    ) or_return,
  }

  if vk.AllocateMemory(ctx.device.handle, &alloc_info, nil, &memory) != .SUCCESS do return memory, .AllocateDeviceMemory
  vk.BindBufferMemory(ctx.device.handle, buffer, memory, 0)

  return memory, nil
}

@private
copy_data :: proc($T: typeid, ctx: ^Vulkan_Context, data: []T, dst_buffer: vk.Buffer, dst_offset: u32) -> error.Error {
  l := u32(len(data))

  if ctx.staging.buffer.len + l > ctx.staging.buffer.cap {
    return .OutOfStagingMemory
  }

  size := u32(l * size_of(T))
  offset := vk.DeviceSize(ctx.staging.buffer.len)

  out: [^]T
  vk.MapMemory(ctx.device.handle, ctx.staging.buffer.memory, offset, vk.DeviceSize(size), {}, (^rawptr)(&out))
  copy(out[0:l], data)
  vk.UnmapMemory(ctx.device.handle, ctx.staging.buffer.memory)

  defer ctx.staging.buffer.len += size

  copy_info := vk.BufferCopy {
    srcOffset = offset,
    dstOffset = vk.DeviceSize(dst_offset * size_of(T)),
    size      = vk.DeviceSize(size),
  }

  if !ctx.staging.recording {
    begin_info := vk.CommandBufferBeginInfo {
      sType = .COMMAND_BUFFER_BEGIN_INFO,
      flags = {.ONE_TIME_SUBMIT},
    }

    if vk.BeginCommandBuffer(ctx.command_buffers[1], &begin_info) != .SUCCESS do return .BeginCommandBufferFailed

    ctx.staging.recording = true
  }

  vk.CmdCopyBuffer(ctx.command_buffers[1], ctx.staging.buffer.handle, dst_buffer, 1, &copy_info)

  return nil
}

@private
find_memory_type :: proc(physical_device: vk.PhysicalDevice, type_filter: u32, properties: vk.MemoryPropertyFlags) -> (u32, error.Error) {
	mem_properties: vk.PhysicalDeviceMemoryProperties
	vk.GetPhysicalDeviceMemoryProperties(physical_device, &mem_properties)

	for i in 0 ..< mem_properties.memoryTypeCount {
		if (type_filter & (1 << i) != 0) && (mem_properties.memoryTypes[i].propertyFlags & properties) == properties do return i, nil
	}

	return 0, .MemoryNotFound
}

buffer_destroy :: proc(ctx: ^Vulkan_Context, buffer: Buffer) {
  vk.DestroyBuffer(ctx.device.handle, buffer.handle, nil)
  vk.FreeMemory(ctx.device.handle, buffer.memory, nil)
}
