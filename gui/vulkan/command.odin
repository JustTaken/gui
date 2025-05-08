package vulk

import vk "vendor:vulkan"
import "./../error"

create_command_pool :: proc(ctx: ^Vulkan_Context, queue_index: u32) -> (vk.CommandPool, error.Error) {
	pool_info: vk.CommandPoolCreateInfo
	pool_info.sType = .COMMAND_POOL_CREATE_INFO
	pool_info.flags = {.RESET_COMMAND_BUFFER}
	pool_info.queueFamilyIndex = queue_index

	command_pool: vk.CommandPool
	if vk.CreateCommandPool(ctx.device, &pool_info, nil, &command_pool) != .SUCCESS do return command_pool, .CreateCommandPoolFailed

	return command_pool, nil
}

allocate_command_buffers :: proc(ctx: ^Vulkan_Context, command_pool: vk.CommandPool, count: u32) -> (command_buffers: []vk.CommandBuffer, err: error.Error) {
	alloc_info: vk.CommandBufferAllocateInfo
	alloc_info.sType = .COMMAND_BUFFER_ALLOCATE_INFO
	alloc_info.commandPool = command_pool
	alloc_info.level = .PRIMARY
	alloc_info.commandBufferCount = count

	command_buffers = make([]vk.CommandBuffer, count, ctx.allocator)
	if res := vk.AllocateCommandBuffers(ctx.device, &alloc_info, &command_buffers[0]); res != .SUCCESS do return command_buffers, .AllocateCommandBufferFailed

	return command_buffers, nil
}

