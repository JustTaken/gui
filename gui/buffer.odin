package main

import vk "vendor:vulkan"
import wl "wayland"
import "core:fmt"

StagingBuffer :: struct {
  buffer: vk.Buffer,
  memory: vk.DeviceMemory,
  len: u32,
  capacity: u32,
  recording: bool,
}

Buffer :: struct {
  data: []u8,
  id: u32,
  offset: u32,

  width: u32,
  height: u32,

  released: bool,
  bound: bool,

  frame: ^Frame,
  next: ^Buffer,
}

create_staging_buffer :: proc(ctx: ^VulkanContext, size: vk.DeviceSize) -> bool {
  ctx.staging.buffer = vulkan_buffer_create(ctx.device, size, { .TRANSFER_SRC }) or_return
  ctx.staging.memory = vulkan_buffer_create_memory(ctx.device, ctx.physical_device, ctx.staging.buffer, { .HOST_COHERENT, .HOST_VISIBLE }) or_return
  ctx.staging.len = 0
  ctx.staging.capacity = u32(size)

  return true
}

update_projection :: proc(ctx: ^VulkanContext, projection: Projection) -> bool {
  m := [?]Projection{ projection }
  offset := vulkan_buffer_copy_data(Projection, ctx, m[:])

  vulkan_buffer_copy(ctx, ctx.uniform_buffer, size_of(Projection), 0, offset) or_return

  return true
}

vulkan_buffer_create :: proc(device: vk.Device, size: vk.DeviceSize, usage: vk.BufferUsageFlags) -> (vk.Buffer, bool) {
  buf_info := vk.BufferCreateInfo {
    sType = .BUFFER_CREATE_INFO,
    pNext = nil,
    size = size,
    usage = usage,
    flags = {},
    sharingMode = .EXCLUSIVE,
  }

  buffer: vk.Buffer
  if vk.CreateBuffer(device, &buf_info, nil, &buffer) != .SUCCESS do return buffer, false

  return buffer, true
}

vulkan_buffer_create_memory :: proc(device: vk.Device , physical_device: vk.PhysicalDevice, buffer: vk.Buffer, properties: vk.MemoryPropertyFlags) -> (memory: vk.DeviceMemory, ok: bool) {
  requirements: vk.MemoryRequirements
  vk.GetBufferMemoryRequirements(device, buffer, &requirements)

  alloc_info := vk.MemoryAllocateInfo{
    sType = .MEMORY_ALLOCATE_INFO,
    pNext = nil,
    allocationSize = requirements.size,
    memoryTypeIndex = find_memory_type(physical_device, requirements.memoryTypeBits, properties) or_return
  }

  if vk.AllocateMemory(device, &alloc_info, nil, &memory) != .SUCCESS do return memory, false

  vk.BindBufferMemory(device, buffer, memory, 0)

  return memory, true
}

vulkan_buffer_copy :: proc(ctx: ^VulkanContext, dst_buffer: vk.Buffer, size: vk.DeviceSize, dst_offset: vk.DeviceSize, src_offset: vk.DeviceSize) -> bool {
  copy_info := vk.BufferCopy {
    srcOffset = src_offset,
    dstOffset = dst_offset,
    size = size,
  }

  if !ctx.staging.recording {
    begin_info := vk.CommandBufferBeginInfo {
      sType = .COMMAND_BUFFER_BEGIN_INFO,
      flags = { .ONE_TIME_SUBMIT },
    }

    if vk.BeginCommandBuffer(ctx.command_buffers[1], &begin_info) != .SUCCESS do return false
    ctx.staging.recording = true
  }

  vk.CmdCopyBuffer(ctx.command_buffers[1], ctx.staging.buffer, dst_buffer, 1, &copy_info)

  return true
}

vulkan_buffer_copy_data :: proc($T: typeid, ctx: ^VulkanContext, data: []T) -> vk.DeviceSize {
  out: [^]T

  l := len(data)
  size := u32(l * size_of(T))
  offset := vk.DeviceSize(ctx.staging.len)

  vk.MapMemory(ctx.device, ctx.staging.memory, offset, vk.DeviceSize(size), {}, (^rawptr)(&out))
  copy(out[0:l], data)
  vk.UnmapMemory(ctx.device, ctx.staging.memory)

  defer ctx.staging.len += size

  return offset
}

wayland_buffer_write_swap :: proc(ctx: ^WaylandContext, buffer: ^Buffer, width: u32, height: u32) -> bool {
  if !buffer.released {
    fmt.println("Buffer is not ready")
    return false
  }

  defer buffer.released = false

  if buffer.width != width || buffer.height != height {
    if buffer.bound do write(ctx, { }, buffer.id, ctx.destroy_buffer_opcode)

    resize_frame(ctx.vk, buffer.frame, width, height) or_return
    wayland_buffer_create(ctx, buffer, width, height)
  }

  frame_draw(ctx.vk, buffer.frame, width, height) or_return

  write(ctx, { wl.Object(buffer.id), wl.Int(0), wl.Int(0) }, ctx.surface_id, ctx.surface_attach_opcode)
  write(ctx, { wl.Int(0), wl.Int(0), wl.Int(width), wl.Int(height) }, ctx.surface_id, ctx.surface_damage_opcode)
  write(ctx, { }, ctx.surface_id, ctx.surface_commit_opcode)

  ctx.buffer = buffer.next

  return true
}

wayland_buffers_init :: proc(ctx: ^WaylandContext) -> bool {
  ctx.buffers[0].id = ctx.buffer_base_id
  for i in 0..<len(ctx.buffers) {
    buffer := &ctx.buffers[i]

    if i != 0 do buffer.id = copy_id(ctx, ctx.buffer.id)

    buffer.frame = get_frame(ctx.vk, buffer.id - ctx.buffer_base_id)
    buffer.released = true
    buffer.bound = false
    buffer.width = 0
    buffer.height = 0
  }

  return true
}

wayland_buffer_create :: proc(ctx: ^WaylandContext, buffer: ^Buffer, width: u32, height: u32) {
    buffer.bound = true

    write(ctx, { wl.BoundNewId(ctx.dma_params_id) }, ctx.dma_id, ctx.dma_create_param_opcode)

    for i in 0..<buffer.frame.modifier.drmFormatModifierPlaneCount {
      plane := &buffer.frame.planes[i]
      modifier_hi := (buffer.frame.modifier.drmFormatModifier & 0xFFFFFFFF00000000) >> 32
      modifier_lo := buffer.frame.modifier.drmFormatModifier & 0x00000000FFFFFFFF

      write(ctx, { wl.Fd(buffer.frame.fd), wl.Uint(i), wl.Uint(plane.offset), wl.Uint(plane.rowPitch), wl.Uint(modifier_hi), wl.Uint(modifier_lo) }, ctx.dma_params_id, ctx.dma_params_add_opcode)
    }

    buffer.width = width
    buffer.height = height

    format := drm_format(ctx.vk.format)

    write(ctx, { wl.BoundNewId(buffer.id), wl.Int(width), wl.Int(height), wl.Uint(format), wl.Uint(0) }, ctx.dma_params_id, ctx.dma_params_create_immed_opcode)
    write(ctx, { }, ctx.dma_params_id, ctx.dma_params_destroy_opcode)
}
