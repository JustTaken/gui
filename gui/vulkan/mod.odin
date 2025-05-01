package vulk

import "base:runtime"
import "core:dynlib"
import "core:fmt"
import "core:mem"
import "core:sys/posix"
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
	queue_indices:   [2]u32,
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
	ctx.physical_device = find_physical_device(ctx, ctx.instance) or_return
	ctx.modifiers = get_drm_modifiers(ctx, ctx.physical_device, ctx.format) or_return
	ctx.queue_indices = find_queue_indices(ctx, ctx.physical_device) or_return
	ctx.device = create_device(ctx, ctx.physical_device, ctx.queue_indices[:]) or_return
	ctx.render_pass = create_render_pass(ctx) or_return
	ctx.descriptor_pool = create_descriptor_pool(ctx.device) or_return
	ctx.set_layout = create_set_layout(ctx, ctx.device) or_return
	ctx.layout = create_layout(ctx.device, ctx.set_layout.handle) or_return

	ctx.pipeline = create_pipeline(ctx, ctx.device, ctx.layout, ctx.render_pass, width, height) or_return

	ctx.geometries = collection.new_vec(Geometry, 20, ctx.allocator)
	ctx.instances = collection.new_vec(Instance, 20, ctx.allocator)

	ctx.queues = create_queues(ctx, ctx.device, ctx.queue_indices[:]) or_return
	ctx.command_pool = create_command_pool(ctx.device, ctx.queue_indices[1]) or_return
	ctx.command_buffers = allocate_command_buffers(ctx, ctx.device, ctx.command_pool, 2) or_return
	ctx.draw_fence = create_fence(ctx.device) or_return
	ctx.copy_fence = create_fence(ctx.device) or_return
	ctx.semaphore = create_semaphore(ctx.device) or_return

	ctx.staging.buffer = buffer_create(ctx, size_of(Matrix) * 256 * 1000, {.TRANSFER_SRC}, {.HOST_COHERENT, .HOST_VISIBLE}) or_return
	frames_init(ctx, frame_count, width, height) or_return
	descriptor_set_create(ctx, ctx.set_layout, {{.UNIFORM_BUFFER, .TRANSFER_DST}, {.STORAGE_BUFFER, .TRANSFER_DST}, {.STORAGE_BUFFER, .TRANSFER_DST}, {.STORAGE_BUFFER, .TRANSFER_DST}}, {{.DEVICE_LOCAL}, {.DEVICE_LOCAL}, {.DEVICE_LOCAL}, {.DEVICE_LOCAL}}, {2, 20, 20, 1}) or_return

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

@(private = "file")
create_instance :: proc(ctx: ^Vulkan_Context) -> (instance: vk.Instance, ok: Error) {
	layer_count: u32
	vk.EnumerateInstanceLayerProperties(&layer_count, nil)
	layers := make([]vk.LayerProperties, layer_count, ctx.tmp_allocator)
	vk.EnumerateInstanceLayerProperties(&layer_count, &layers[0])

	check :: proc(v: cstring, availables: []vk.LayerProperties) -> Error {
		for &available in availables do if v == cstring(&available.layerName[0]) do return nil

		return .LayerNotFound
	}

	app_info := vk.ApplicationInfo {
		sType              = .APPLICATION_INFO,
		pApplicationName   = "Hello Triangle",
		applicationVersion = vk.MAKE_VERSION(0, 0, 1),
		pEngineName        = "No Engine",
		engineVersion      = vk.MAKE_VERSION(0, 0, 1),
		apiVersion         = vk.MAKE_VERSION(1, 4, 3),
	}

	create_info := vk.InstanceCreateInfo {
		sType               = .INSTANCE_CREATE_INFO,
		pApplicationInfo    = &app_info,
		ppEnabledLayerNames = &VALIDATION_LAYERS[0],
		enabledLayerCount   = len(VALIDATION_LAYERS),
	}

	if vk.CreateInstance(&create_info, nil, &instance) != .SUCCESS do return instance, .CreateInstanceFailed

	vk.load_proc_addresses_instance(instance)

	return instance, nil
}

@(private = "file")
create_device :: proc(ctx: ^Vulkan_Context, physical_device: vk.PhysicalDevice, indices: []u32) -> (device: vk.Device, err: Error) {
	queue_priority := f32(1.0)

	unique_indices: [10]u32 = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
	for i in indices {
		if i != indices[0] do panic("Not accepting diferent queue indices for now")
		unique_indices[i] += 1
	}

	queue_create_infos := make([]vk.DeviceQueueCreateInfo, u32(len(indices)), ctx.tmp_allocator)
	defer delete(queue_create_infos)

	count: u32 = 0
	for k, i in unique_indices {
		if k == 0 do continue

		queue_create_info := vk.DeviceQueueCreateInfo {
			sType            = .DEVICE_QUEUE_CREATE_INFO,
			queueFamilyIndex = u32(i),
			queueCount       = 1,
			pQueuePriorities = &queue_priority,
		}

		queue_create_infos[count] = queue_create_info
		count += 1
	}

	feature_info := vk.PhysicalDeviceVulkan13Features {
		sType            = .PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
		synchronization2 = true,
	}

	device_create_info := vk.DeviceCreateInfo {
		sType                   = .DEVICE_CREATE_INFO,
		pNext                   = &feature_info,
		enabledExtensionCount   = u32(len(DEVICE_EXTENSIONS)),
		ppEnabledExtensionNames = &DEVICE_EXTENSIONS[0],
		pQueueCreateInfos       = &queue_create_infos[0],
		queueCreateInfoCount    = count,
		pEnabledFeatures        = nil,
		enabledLayerCount       = 0,
	}

	if vk.CreateDevice(physical_device, &device_create_info, nil, &device) != .SUCCESS do return device, .CreateDeviceFailed

	vk.load_proc_addresses_device(device)

	return device, nil
}

@(private = "file")
get_drm_modifiers :: proc(ctx: ^Vulkan_Context, physical_device: vk.PhysicalDevice, format: vk.Format) -> (modifiers: []vk.DrmFormatModifierPropertiesEXT, err: Error) {
	l: u32 = 0

	render_features: vk.FormatFeatureFlags = {.COLOR_ATTACHMENT, .COLOR_ATTACHMENT_BLEND}
	texture_features: vk.FormatFeatureFlags = {.SAMPLED_IMAGE, .SAMPLED_IMAGE_FILTER_LINEAR}

	modifier_properties_list := vk.DrmFormatModifierPropertiesListEXT {
		sType = .DRM_FORMAT_MODIFIER_PROPERTIES_LIST_EXT,
	}

	properties := vk.FormatProperties2 {
		sType = .FORMAT_PROPERTIES_2,
		pNext = &modifier_properties_list,
	}

	vk.GetPhysicalDeviceFormatProperties2(physical_device, format, &properties)
	count := modifier_properties_list.drmFormatModifierCount

	modifiers = make([]vk.DrmFormatModifierPropertiesEXT, count, ctx.allocator)
	drmFormatModifierProperties := make([]vk.DrmFormatModifierPropertiesEXT, count, ctx.tmp_allocator)
	modifier_properties_list.pDrmFormatModifierProperties = &drmFormatModifierProperties[0]

	vk.GetPhysicalDeviceFormatProperties2(physical_device, format, &properties)

	image_modifier_info := vk.PhysicalDeviceImageDrmFormatModifierInfoEXT {
		sType       = .PHYSICAL_DEVICE_IMAGE_DRM_FORMAT_MODIFIER_INFO_EXT,
		sharingMode = .EXCLUSIVE,
	}

	external_image_info := vk.PhysicalDeviceExternalImageFormatInfo {
		sType      = .PHYSICAL_DEVICE_EXTERNAL_IMAGE_FORMAT_INFO,
		pNext      = &image_modifier_info,
		handleType = {.DMA_BUF_EXT},
	}

	image_info := vk.PhysicalDeviceImageFormatInfo2 {
		sType  = .PHYSICAL_DEVICE_IMAGE_FORMAT_INFO_2,
		pNext  = &external_image_info,
		format = format,
		type   = .D2,
		tiling = .DRM_FORMAT_MODIFIER_EXT,
	}

	external_image_properties := vk.ExternalImageFormatProperties {
		sType = .EXTERNAL_IMAGE_FORMAT_PROPERTIES,
	}

	image_properties := vk.ImageFormatProperties2 {
		sType = .IMAGE_FORMAT_PROPERTIES_2,
		pNext = &external_image_properties,
	}

	emp := &external_image_properties.externalMemoryProperties

	for i in 0 ..< count {
		modifier_properties := modifier_properties_list.pDrmFormatModifierProperties[i]
		image_modifier_info.drmFormatModifier = modifier_properties.drmFormatModifier

		if modifier_properties.drmFormatModifierTilingFeatures < render_features do continue
		if modifier_properties.drmFormatModifierTilingFeatures < texture_features do continue

		image_info.usage = {.COLOR_ATTACHMENT}

		if vk.GetPhysicalDeviceImageFormatProperties2(physical_device, &image_info, &image_properties) != .SUCCESS do continue
		if emp.externalMemoryFeatures < {.IMPORTABLE, .EXPORTABLE} do continue

		image_info.usage = {.SAMPLED}

		if vk.GetPhysicalDeviceImageFormatProperties2(physical_device, &image_info, &image_properties) != .SUCCESS do continue
		if emp.externalMemoryFeatures < {.IMPORTABLE, .EXPORTABLE} do continue

		modifiers[l] = modifier_properties
		l += 1
	}

	return modifiers[0:l], nil
}

@(private = "file")
check_physical_device_ext_support :: proc(ctx: ^Vulkan_Context, physical_device: vk.PhysicalDevice) -> Error {
	count: u32

	vk.EnumerateDeviceExtensionProperties(physical_device, nil, &count, nil)
	available_extensions := make([]vk.ExtensionProperties, count, ctx.tmp_allocator)
	vk.EnumerateDeviceExtensionProperties(physical_device, nil, &count, &available_extensions[0])

	check :: proc(e: cstring, availables: []vk.ExtensionProperties) -> bool {
		for &available in availables do if e == cstring(&available.extensionName[0]) do return true

		return false
	}

	for ext in DEVICE_EXTENSIONS do if !check(ext, available_extensions) do return .ExtensionNotFound

	return nil
}

@(private = "file")
find_physical_device :: proc(ctx: ^Vulkan_Context, instance: vk.Instance) -> (physical_device: vk.PhysicalDevice, err: Error) {
	device_count: u32
	vk.EnumeratePhysicalDevices(instance, &device_count, nil)
	devices := make([]vk.PhysicalDevice, device_count, ctx.tmp_allocator)
	vk.EnumeratePhysicalDevices(instance, &device_count, &devices[0])

	suitability :: proc(ctx: ^Vulkan_Context, dev: vk.PhysicalDevice) -> u32 {
		props: vk.PhysicalDeviceProperties
		features: vk.PhysicalDeviceFeatures

		vk.GetPhysicalDeviceProperties(dev, &props)
		vk.GetPhysicalDeviceFeatures(dev, &features)

		score: u32 = 10
		if props.deviceType == .DISCRETE_GPU do score += 1000

		if check_physical_device_ext_support(ctx, dev) != nil do return 0

		return score + props.limits.maxImageDimension2D
	}

	hiscore: u32 = 0
	for dev in devices {
		score := suitability(ctx, dev)
		if score > hiscore {
			physical_device = dev
			hiscore = score
		}
	}

	if hiscore == 0 do return physical_device, .PhysicalDeviceNotFound

	return physical_device, nil
}

@(private = "file")
create_queues :: proc(ctx: ^Vulkan_Context, device: vk.Device, queue_indices: []u32) -> (queues: []vk.Queue, err: Error) {
	queues = make([]vk.Queue, u32(len(queue_indices)), ctx.allocator)
	for &q, i in &queues {
		vk.GetDeviceQueue(device, u32(queue_indices[i]), 0, &q)
	}

	return queues, nil
}

@(private = "file")
find_queue_indices :: proc(ctx: ^Vulkan_Context, physical_device: vk.PhysicalDevice) -> (indices: [2]u32, err: Error) {
	MAX: u32 = 0xFF
	indices = [2]u32{MAX, MAX}

	queue_count: u32
	vk.GetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_count, nil)
	available_queues := make([]vk.QueueFamilyProperties, queue_count, ctx.tmp_allocator)
	vk.GetPhysicalDeviceQueueFamilyProperties(
		physical_device,
		&queue_count,
		raw_data(available_queues),
	)

	for v, i in available_queues {
		if .GRAPHICS in v.queueFlags && indices[0] == MAX do indices[0] = u32(i)
		if .TRANSFER in v.queueFlags && indices[1] == MAX do indices[1] = u32(i)
	}

	for indice in indices {
		if indice == MAX do return indices, .FamilyIndiceNotComplete
	}

	return indices, nil
}

@(private = "file")
create_command_pool :: proc(device: vk.Device, queue_index: u32) -> (vk.CommandPool, Error) {
	pool_info: vk.CommandPoolCreateInfo
	pool_info.sType = .COMMAND_POOL_CREATE_INFO
	pool_info.flags = {.RESET_COMMAND_BUFFER}
	pool_info.queueFamilyIndex = queue_index

	command_pool: vk.CommandPool
	if vk.CreateCommandPool(device, &pool_info, nil, &command_pool) != .SUCCESS do return command_pool, .CreateCommandPoolFailed

	return command_pool, nil
}

@(private = "file")
allocate_command_buffers :: proc(ctx: ^Vulkan_Context, device: vk.Device, command_pool: vk.CommandPool, count: u32) -> (command_buffers: []vk.CommandBuffer, err: Error) {
	alloc_info: vk.CommandBufferAllocateInfo
	alloc_info.sType = .COMMAND_BUFFER_ALLOCATE_INFO
	alloc_info.commandPool = command_pool
	alloc_info.level = .PRIMARY
	alloc_info.commandBufferCount = count

	command_buffers = make([]vk.CommandBuffer, count, ctx.allocator)
	if res := vk.AllocateCommandBuffers(device, &alloc_info, &command_buffers[0]); res != .SUCCESS do return command_buffers, .AllocateCommandBufferFailed

	return command_buffers, nil
}

@(private = "file")
create_fence :: proc(device: vk.Device) -> (vk.Fence, Error) {
	info := vk.FenceCreateInfo {
		sType = .FENCE_CREATE_INFO,
		flags = {.SIGNALED},
	}

	fence: vk.Fence
	if vk.CreateFence(device, &info, nil, &fence) != .SUCCESS do return fence, .CreateFenceFailed

	return fence, nil
}

@(private = "file")
create_semaphore :: proc(device: vk.Device) -> (vk.Semaphore, Error) {
	info := vk.SemaphoreCreateInfo {
		sType = .SEMAPHORE_CREATE_INFO,
		flags = {},
	}

	semaphore: vk.Semaphore
	if vk.CreateSemaphore(device, &info, nil, &semaphore) != .SUCCESS do return semaphore, .CreateSemaphoreFailed

	return semaphore, nil
}

drm_format :: proc(format: vk.Format) -> u32 {
	#partial switch format {
	case .B8G8R8A8_SRGB:
		return (u32(u8('X'))) | (u32(u8('R')) << 8) | (u32(u8('2')) << 16) | (u32(u8('4')) << 24)
	}

	return 0
}

find_memory_type :: proc(physical_device: vk.PhysicalDevice, type_filter: u32, properties: vk.MemoryPropertyFlags) -> (u32, Error) {
	mem_properties: vk.PhysicalDeviceMemoryProperties
	vk.GetPhysicalDeviceMemoryProperties(physical_device, &mem_properties)

	for i in 0 ..< mem_properties.memoryTypeCount {
		if (type_filter & (1 << i) != 0) && (mem_properties.memoryTypes[i].propertyFlags & properties) == properties do return i, nil
	}

	return 0, .MemoryNotFound
}

load_fn :: proc(ptr: rawptr, name: cstring) {
	(cast(^rawptr)ptr)^ = dynlib.symbol_address(library, string(name))
}
