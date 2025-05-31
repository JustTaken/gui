package vulk

import "lib:collection/vector"
import "lib:error"
import vk "vendor:vulkan"

Command_Buffer :: struct {
  handle: vk.CommandBuffer,
  pool:   ^Command_Pool,
}

Command_Pool :: struct {
  handle: vk.CommandPool,
  childs: vector.Vector(Command_Buffer),
  queue:  ^Queue,
}

@(private)
command_pool_create :: proc(
  ctx: ^Vulkan_Context,
  queue: ^Queue,
  command_buffer_count: u32,
) -> (
  command_pool: ^Command_Pool,
  err: error.Error,
) {
  command_pool = vector.one(&queue.command_pools) or_return
  command_pool.childs = vector.new(
    Command_Buffer,
    command_buffer_count,
    ctx.allocator,
  ) or_return

  pool_info: vk.CommandPoolCreateInfo
  pool_info.sType = .COMMAND_POOL_CREATE_INFO
  pool_info.flags = {.RESET_COMMAND_BUFFER}
  pool_info.queueFamilyIndex = queue.indice

  if vk.CreateCommandPool(
       ctx.device.handle,
       &pool_info,
       nil,
       &command_pool.handle,
     ) !=
     .SUCCESS {
    return command_pool, .CreateCommandPoolFailed
  }

  command_pool.queue = queue

  return command_pool, nil
}

@(private)
command_buffer_allocate :: proc(
  ctx: ^Vulkan_Context,
  command_pool: ^Command_Pool,
) -> (
  command_buffer: ^Command_Buffer,
  err: error.Error,
) {
  command_buffers := command_buffers_allocate(ctx, command_pool, 1) or_return
  command_buffer = &command_buffers[0]

  return command_buffer, nil
}

@(private)
command_buffers_allocate :: proc(
  ctx: ^Vulkan_Context,
  command_pool: ^Command_Pool,
  count: u32,
) -> (
  command_buffers: []Command_Buffer,
  err: error.Error,
) {
  alloc_info: vk.CommandBufferAllocateInfo
  alloc_info.sType = .COMMAND_BUFFER_ALLOCATE_INFO
  alloc_info.commandPool = command_pool.handle
  alloc_info.level = .PRIMARY
  alloc_info.commandBufferCount = count

  command_buffers = vector.reserve_n(&command_pool.childs, count) or_return

  if res := vk.AllocateCommandBuffers(
    ctx.device.handle,
    &alloc_info,
    &command_buffers[0].handle,
  ); res != .SUCCESS {
    return command_buffers, .AllocateCommandBufferFailed
  }

  for &command_buffer in command_buffers {
    command_buffer.pool = command_pool
  }

  return command_buffers, nil
}

@(private)
command_buffer_begin :: proc(
  ctx: ^Vulkan_Context,
  command_buffer: ^Command_Buffer,
) -> error.Error {
  begin_info := vk.CommandBufferBeginInfo {
    sType = .COMMAND_BUFFER_BEGIN_INFO,
    flags = {.ONE_TIME_SUBMIT},
  }

  if vk.BeginCommandBuffer(command_buffer.handle, &begin_info) != .SUCCESS do return .BeginCommandBufferFailed

  return nil
}

@(private)
command_buffer_end :: proc(
  ctx: ^Vulkan_Context,
  command_buffer: ^Command_Buffer,
  fence: vk.Fence,
) -> error.Error {
  if vk.EndCommandBuffer(command_buffer.handle) != .SUCCESS do return .EndCommandBufferFailed

  transfer_submit_info := vk.SubmitInfo {
    sType              = .SUBMIT_INFO,
    commandBufferCount = 1,
    pCommandBuffers    = &command_buffer.handle,
  }

  fences := []vk.Fence{fence}
  vk.ResetFences(ctx.device.handle, 1, &fences[0])
  if vk.QueueSubmit(command_buffer.pool.queue.handle, 1, &transfer_submit_info, fence) != .SUCCESS do return .QueueSubmitFailed
  if vk.WaitForFences(ctx.device.handle, 1, &fences[0], true, 0xFFFFFF) != .SUCCESS do return .WaitFencesFailed

  return nil
}
