package vulk

import "base:runtime"
import "core:dynlib"
import "core:fmt"
import "core:mem"
import "core:sys/posix"
import "core:log"
import vk "vendor:vulkan"

import "./../collection"

library: dynlib.Library

VALIDATION_LAYERS := [?]cstring{"VK_LAYER_KHRONOS_validation"}

DEVICE_EXTENSIONS := [?]cstring {
	"VK_KHR_external_memory_fd",
	"VK_EXT_external_memory_dma_buf",
	"VK_EXT_image_drm_format_modifier",
}

PLANE_INDICES := [?]vk.ImageAspectFlag {
	.MEMORY_PLANE_0_EXT,
	.MEMORY_PLANE_1_EXT,
	.MEMORY_PLANE_2_EXT,
	.MEMORY_PLANE_3_EXT,
}


InstanceModel :: matrix[4, 4]f32
Color :: [4]f32
Light :: [3]f32

Vertex :: struct {
  position: [3]f32,
  normal:   [3]f32,
  texture:  [2]f32,
}

Matrix :: matrix[4, 4]f32

Vulkan_Context :: struct {
	instance:        vk.Instance,
	device:          vk.Device,
	physical_device: vk.PhysicalDevice,
	queues:          []vk.Queue,
	queue_indices:   []u32,
	set_layout:     Descriptor_Set_Layout,
	layout:          vk.PipelineLayout,
	pipeline:        vk.Pipeline,
	render_pass:     vk.RenderPass,
	command_pool:    vk.CommandPool,
	command_buffers: []vk.CommandBuffer,
	staging:         StagingBuffer,
	descriptor_pool: vk.DescriptorPool,
	descriptor_set: Descriptor_Set,
	frames:          []Frame,
	geometries:      collection.Vector(Geometry),
	instances: collection.Vector(Instance),
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

init_vulkan :: proc(ctx: ^Vulkan_Context, width: u32, height: u32, frame_count: u32, arena: ^mem.Arena, tmp_arena: ^mem.Arena) -> Error {
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
	ctx.queue_indices = find_queue_indices(ctx) or_return
	ctx.device = create_device(ctx) or_return
	ctx.render_pass = create_render_pass(ctx) or_return
	ctx.descriptor_pool = create_descriptor_pool(ctx) or_return
	ctx.set_layout = create_set_layout(ctx) or_return
	ctx.layout = create_layout(ctx, ctx.set_layout) or_return
	ctx.pipeline = create_pipeline(ctx, ctx.layout, ctx.render_pass, width, height) or_return

	ctx.queues = create_queues(ctx, ctx.queue_indices) or_return
	ctx.command_pool = create_command_pool(ctx, ctx.queue_indices[1]) or_return
	ctx.command_buffers = allocate_command_buffers(ctx, ctx.command_pool, 2) or_return
	ctx.draw_fence = create_fence(ctx) or_return
	ctx.copy_fence = create_fence(ctx) or_return
	ctx.semaphore = create_semaphore(ctx) or_return

	ctx.staging.buffer = buffer_create(ctx, size_of(Matrix) * 256 * 1000, {.TRANSFER_SRC}, {.HOST_COHERENT, .HOST_VISIBLE}) or_return
	ctx.descriptor_set = descriptor_set_create(ctx, ctx.set_layout, {{.UNIFORM_BUFFER, .TRANSFER_DST}, {.STORAGE_BUFFER, .TRANSFER_DST}, {.STORAGE_BUFFER, .TRANSFER_DST}, {.STORAGE_BUFFER, .TRANSFER_DST}}, {{.DEVICE_LOCAL}, {.DEVICE_LOCAL}, {.DEVICE_LOCAL}, {.DEVICE_LOCAL}}, {2, 20, 20, 1}) or_return
	ctx.frames = frames_create(ctx, frame_count, width, height) or_return

	ctx.geometries = collection.new_vec(Geometry, 20, ctx.allocator)
	ctx.instances = collection.new_vec(Instance, 20, ctx.allocator)

	return nil
}

deinit_vulkan :: proc(ctx: ^Vulkan_Context) {
	vk.WaitForFences(ctx.device, 1, &ctx.draw_fence, true, 0xFFFFFF)
	vk.WaitForFences(ctx.device, 1, &ctx.copy_fence, true, 0xFFFFFF)

	vk.DestroyBuffer(ctx.device, ctx.staging.buffer.handle, nil)
	vk.FreeMemory(ctx.device, ctx.staging.buffer.memory, nil)
	vk.DestroySemaphore(ctx.device, ctx.semaphore, nil)
	vk.DestroyFence(ctx.device, ctx.draw_fence, nil)
	vk.DestroyFence(ctx.device, ctx.copy_fence, nil)

	for descriptor in ctx.descriptor_set.descriptors {
		vk.DestroyBuffer(ctx.device, descriptor.buffer.handle, nil)
		vk.FreeMemory(ctx.device, descriptor.buffer.memory, nil)
	}

	for i in 0 ..< ctx.geometries.len {
		destroy_geometry(ctx.device, &ctx.geometries.data[i])
	}

	for &frame in ctx.frames {
		destroy_frame(ctx.device, &frame)
	}

	vk.DestroyCommandPool(ctx.device, ctx.command_pool, nil)
	vk.DestroyDescriptorPool(ctx.device, ctx.descriptor_pool, nil)
	vk.DestroyPipeline(ctx.device, ctx.pipeline, nil)
	vk.DestroyPipelineLayout(ctx.device, ctx.layout, nil)

	vk.DestroyDescriptorSetLayout(ctx.device, ctx.set_layout.handle, nil)

	vk.DestroyRenderPass(ctx.device, ctx.render_pass, nil)
	vk.DestroyDevice(ctx.device, nil)
	vk.DestroyInstance(ctx.instance, nil)

	_ = dynlib.unload_library(library)
}


load_fn :: proc(ptr: rawptr, name: cstring) {
	(cast(^rawptr)ptr)^ = dynlib.symbol_address(library, string(name))
}
