package vulk

import vk "vendor:vulkan"
import "lib:error"
import "lib:collection/vector"

@private
command_pool_create :: proc(ctx: ^Vulkan_Context, queue: Queue) -> (command_pool: vk.CommandPool, err: error.Error) {
  pool_info: vk.CommandPoolCreateInfo
  pool_info.sType = .COMMAND_POOL_CREATE_INFO
  pool_info.flags = {.RESET_COMMAND_BUFFER}
  pool_info.queueFamilyIndex = queue.indice

  if vk.CreateCommandPool(ctx.device.handle, &pool_info, nil, &command_pool) != .SUCCESS {
    return command_pool, .CreateCommandPoolFailed
  }

  return command_pool, nil
}

@private
command_buffers_allocate :: proc(ctx: ^Vulkan_Context, command_pool: vk.CommandPool, count: u32) -> (command_buffers: vector.Vector(vk.CommandBuffer), err: error.Error) {
  alloc_info: vk.CommandBufferAllocateInfo
  alloc_info.sType = .COMMAND_BUFFER_ALLOCATE_INFO
  alloc_info.commandPool = command_pool
  alloc_info.level = .PRIMARY
  alloc_info.commandBufferCount = count

  command_buffers = vector.new(vk.CommandBuffer, count, ctx.allocator) or_return
  if res := vk.AllocateCommandBuffers(ctx.device.handle, &alloc_info, &command_buffers.data[0]); res != .SUCCESS {
    return command_buffers, .AllocateCommandBufferFailed
  }

  return command_buffers, nil
}

