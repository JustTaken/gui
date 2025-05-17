package vulk

import vk "vendor:vulkan"
import "./../error"

Queue :: struct {
	handle: vk.Queue,
	indice: u32,
}

@private
Device :: struct {
	handle: vk.Device,
	queues: []Queue,
}

@private
PLANE_INDICES := [?]vk.ImageAspectFlag {
	.MEMORY_PLANE_0_EXT,
	.MEMORY_PLANE_1_EXT,
	.MEMORY_PLANE_2_EXT,
	.MEMORY_PLANE_3_EXT,
}

@private
get_drm_modifiers :: proc(ctx: ^Vulkan_Context) -> (modifiers: []vk.DrmFormatModifierPropertiesEXT, err: error.Error) {
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

	vk.GetPhysicalDeviceFormatProperties2(ctx.physical_device, ctx.format, &properties)
	count := modifier_properties_list.drmFormatModifierCount

	modifiers = make([]vk.DrmFormatModifierPropertiesEXT, count, ctx.allocator)
	drmFormatModifierProperties := make([]vk.DrmFormatModifierPropertiesEXT, count, ctx.tmp_allocator)
	modifier_properties_list.pDrmFormatModifierProperties = &drmFormatModifierProperties[0]

	vk.GetPhysicalDeviceFormatProperties2(ctx.physical_device, ctx.format, &properties)

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
		format = ctx.format,
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

		if vk.GetPhysicalDeviceImageFormatProperties2(ctx.physical_device, &image_info, &image_properties) != .SUCCESS do continue
		if emp.externalMemoryFeatures < {.IMPORTABLE, .EXPORTABLE} do continue

		image_info.usage = {.SAMPLED}

		if vk.GetPhysicalDeviceImageFormatProperties2(ctx.physical_device, &image_info, &image_properties) != .SUCCESS do continue
		if emp.externalMemoryFeatures < {.IMPORTABLE, .EXPORTABLE} do continue

		modifiers[l] = modifier_properties
		l += 1
	}

	return modifiers[0:l], nil
}

@private
check_physical_device_ext_support :: proc(ctx: ^Vulkan_Context, physical_device: vk.PhysicalDevice) -> error.Error {
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

@private
find_physical_device :: proc(ctx: ^Vulkan_Context) -> (physical_device: vk.PhysicalDevice, err: error.Error) {
	device_count: u32
	vk.EnumeratePhysicalDevices(ctx.instance, &device_count, nil)
	devices := make([]vk.PhysicalDevice, device_count, ctx.tmp_allocator)
	vk.EnumeratePhysicalDevices(ctx.instance, &device_count, &devices[0])

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

@private
queues_indices :: proc(ctx: ^Vulkan_Context) -> (indice: []u32, err: error.Error) {
	MAX: u32 = 0xFF
	indices := make([]u32, 2, ctx.tmp_allocator)

	for &indice in indices {
		indice = MAX
	}

	queue_count: u32
	vk.GetPhysicalDeviceQueueFamilyProperties(ctx.physical_device, &queue_count, nil)
	available_queues := make([]vk.QueueFamilyProperties, queue_count, ctx.tmp_allocator)
	vk.GetPhysicalDeviceQueueFamilyProperties(ctx.physical_device, &queue_count, raw_data(available_queues))

	for v, i in available_queues {
		if .GRAPHICS in v.queueFlags && indices[0] == MAX do indices[0] = u32(i)
		if .TRANSFER in v.queueFlags && indices[1] == MAX do indices[1] = u32(i)
	}

	for indice in indices {
		if indice == MAX do return indices, .FamilyIndiceNotComplete
	}


	return indices, nil
}

@private
device_create :: proc(ctx: ^Vulkan_Context) -> (device: Device, err: error.Error) {
	indices := queues_indices(ctx) or_return
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

	if vk.CreateDevice(ctx.physical_device, &device_create_info, nil, &device.handle) != .SUCCESS do return device, .CreateDeviceFailed

	vk.load_proc_addresses_device(device.handle)

	device.queues = make([]Queue, len(indices), ctx.allocator)

	for i in 0..<len(indices) {
		device.queues[i].indice = indices[i]
		vk.GetDeviceQueue(device.handle, u32(indices[i]), 0, &device.queues[i].handle)
	}

	return device, nil
}

drm_format :: proc(format: vk.Format) -> u32 {
	#partial switch format {
	case .B8G8R8A8_SRGB:
		return (u32(u8('X'))) | (u32(u8('R')) << 8) | (u32(u8('2')) << 16) | (u32(u8('4')) << 24)
	}

	return 0
}
