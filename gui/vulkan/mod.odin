package vulk

import "base:runtime"
import "core:dynlib"
import "core:fmt"
import "core:mem"
import "core:sys/posix"
import "core:log"
import vk "vendor:vulkan"

import "./../collection"
import "./../error"

library: dynlib.Library

@private
VALIDATION_LAYERS := [?]cstring{"VK_LAYER_KHRONOS_validation"}

@private
DEVICE_EXTENSIONS := [?]cstring {
	"VK_KHR_external_memory_fd",
	"VK_EXT_external_memory_dma_buf",
	"VK_EXT_image_drm_format_modifier",
}

Vulkan_Context :: struct {
	instance:        vk.Instance,
	device:          Device,
	physical_device: vk.PhysicalDevice,

	render_pass:     Render_Pass,

	fixed_set: ^Descriptor_Set,
	dynamic_set: ^Descriptor_Set,

	descriptor_pool: Descriptor_Pool,

	command_pool:    vk.CommandPool,
	command_buffers: []vk.CommandBuffer,
	staging:         StagingBuffer,
	frames:          []Frame,
	// geometries:      collection.Vector(Geometry),
	bones: u32,
	copy_fence:      vk.Fence,
	draw_fence:      vk.Fence,
	semaphore:       vk.Semaphore,
	format:          vk.Format,
	depth_format:    vk.Format,
	modifiers:       []vk.DrmFormatModifierPropertiesEXT,
	arena:           ^mem.Arena,
	allocator:       runtime.Allocator,
	tmp_arena:       ^mem.Arena,
	tmp_allocator:   runtime.Allocator,
}

vulkan_init :: proc(ctx: ^Vulkan_Context, width: u32, height: u32, frame_count: u32, arena: ^mem.Arena, tmp_arena: ^mem.Arena) -> error.Error {
	log.info("Initializing Vulkan")

	mark := mem.begin_arena_temp_memory(tmp_arena)
	defer mem.end_arena_temp_memory(mark)

	ok: bool
	if library, ok = dynlib.load_library("libvulkan.so"); !ok do return .VulkanLib
	vk.load_proc_addresses_custom(load_fn)

	ctx.arena = arena
	ctx.allocator = mem.arena_allocator(arena)

	ctx.tmp_arena = tmp_arena
	ctx.tmp_allocator = mem.arena_allocator(tmp_arena)

	ctx.format = .B8G8R8A8_SRGB
	ctx.depth_format = .D32_SFLOAT_S8_UINT

	ctx.instance = create_instance(ctx) or_return
	ctx.physical_device = find_physical_device(ctx) or_return
	ctx.modifiers = get_drm_modifiers(ctx) or_return
	ctx.device = device_create(ctx) or_return
	ctx.descriptor_pool = descriptor_pool_create(ctx, {{type = .UNIFORM_BUFFER, descriptorCount = 10}, {type = .STORAGE_BUFFER, descriptorCount = 10}}, 2) or_return
	ctx.render_pass = render_pass_create(ctx, {layout_create(ctx, {{binding_create(.UNIFORM_BUFFER, 1, {.VERTEX}, size_of(Matrix)), binding_create(.STORAGE_BUFFER, 1, {.VERTEX}, size_of(Light))}, {binding_create(.STORAGE_BUFFER, 1, {.VERTEX}, size_of(Instance_Model)), binding_create(.STORAGE_BUFFER, 1, {.VERTEX}, size_of(Color)), binding_create(.STORAGE_BUFFER, 1, {.VERTEX}, size_of(Matrix))}}) or_return}) or_return

	ctx.command_pool = command_pool_create(ctx, ctx.device.queues[1]) or_return
	ctx.command_buffers = command_buffers_allocate(ctx, ctx.command_pool, 2) or_return
	ctx.draw_fence = fence_create(ctx) or_return
	ctx.copy_fence = fence_create(ctx) or_return
	ctx.semaphore = semaphore_create(ctx) or_return

	ctx.staging.buffer = buffer_create(ctx, size_of(Matrix) * 256 * 1000, {.TRANSFER_SRC}, {.HOST_COHERENT, .HOST_VISIBLE}) or_return

	ctx.fixed_set = descriptor_set_allocate(ctx, &ctx.descriptor_pool, ctx.render_pass.layouts.data[0].sets.data[0], {{.UNIFORM_BUFFER, 2, {.UNIFORM_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}}, {.STORAGE_BUFFER, 1, {.STORAGE_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}}}) or_return

	ctx.frames = frames_create(ctx, &ctx.render_pass, frame_count, width, height) or_return

	return nil
}

vulkan_deinit :: proc(ctx: ^Vulkan_Context) {
	vk.WaitForFences(ctx.device.handle, 1, &ctx.draw_fence, true, 0xFFFFFF)
	vk.WaitForFences(ctx.device.handle, 1, &ctx.copy_fence, true, 0xFFFFFF)

	buffer_destroy(ctx, ctx.staging.buffer)

	vk.DestroySemaphore(ctx.device.handle, ctx.semaphore, nil)
	vk.DestroyFence(ctx.device.handle, ctx.draw_fence, nil)
	vk.DestroyFence(ctx.device.handle, ctx.copy_fence, nil)

	for &frame in ctx.frames {
		frame_destroy(ctx, &frame)
	}

	descriptor_pool_deinit(ctx, ctx.descriptor_pool)
	render_pass_deinit(ctx, &ctx.render_pass)

	vk.DestroyCommandPool(ctx.device.handle, ctx.command_pool, nil)
	vk.DestroyDevice(ctx.device.handle, nil)
	vk.DestroyInstance(ctx.instance, nil)

	_ = dynlib.unload_library(library)
}

@private
load_fn :: proc(ptr: rawptr, name: cstring) {
	(cast(^rawptr)ptr)^ = dynlib.symbol_address(library, string(name))
}
