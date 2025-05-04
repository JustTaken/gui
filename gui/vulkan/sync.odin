package vulk

import vk "vendor:vulkan"

create_fence :: proc(ctx: ^Vulkan_Context) -> (vk.Fence, Error) {
	info := vk.FenceCreateInfo {
		sType = .FENCE_CREATE_INFO,
		flags = {.SIGNALED},
	}

	fence: vk.Fence
	if vk.CreateFence(ctx.device, &info, nil, &fence) != .SUCCESS do return fence, .CreateFenceFailed

	return fence, nil
}

create_semaphore :: proc(ctx: ^Vulkan_Context) -> (vk.Semaphore, Error) {
	info := vk.SemaphoreCreateInfo {
		sType = .SEMAPHORE_CREATE_INFO,
		flags = {},
	}

	semaphore: vk.Semaphore
	if vk.CreateSemaphore(ctx.device, &info, nil, &semaphore) != .SUCCESS do return semaphore, .CreateSemaphoreFailed

	return semaphore, nil
}
