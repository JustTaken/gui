package main

import vk "vendor:vulkan"
import "core:os"
import "core:fmt"
import "core:mem"
import "core:dynlib"

library: dynlib.Library

Context :: struct {
	instance: vk.Instance,
  device:   vk.Device,
	command_pool: vk.CommandPool,
	command_buffers: []vk.CommandBuffer,
}

DEVICE_EXTENSIONS := [?]cstring{
  "VK_KHR_external_memory_fd",
  "VK_EXT_external_memory_dma_buf",
}

VALIDATION_LAYERS := [?]cstring{
  "VK_LAYER_KHRONOS_validation",
}

main :: proc() {
	ctx: Context

  ok: bool
  if library, ok = dynlib.load_library("libvulkan.so"); !ok {
      fmt.println("Failed to load vulkan library")
      return
  }

  defer _ = dynlib.unload_library(library)
  vk.load_proc_addresses_custom(load_fn)

  init_vulkan(&ctx)
}

init_vulkan :: proc(ctx: ^Context) -> bool {
  instance := create_instance() or_return
	defer vk.DestroyInstance(instance, nil)

	physical_device := find_physical_device(instance) or_return
  queue_indices := find_queue_indices(physical_device) or_return

  device := create_device(physical_device, queue_indices) or_return
  defer vk.DestroyDevice(device, nil)

  queues := create_queues(device, queue_indices)

  return true

  //requirements: vk.MemoryRequirements
	//vk.GetImageMemoryRequirements(device, image, &requirements)
  //memory := createMemory(device, physical_device, requirements, { .HOST_VISIBLE, .HOST_COHERENT }) or_return
	//vk.BindImageMemory(device, image, memory, 0)

  //transfer_pool := createCommandPool(device, queue_indices[1]) or_return
	//command_buffers := allocateCommandBuffers(device, transfer_pool, 1) or_return
  //buffer := createBuffer(device, physical_device, 1920 * 1080 * 4, { .TRANSFER_SRC }, { .HOST_COHERENT, .HOST_VISIBLE }) or_return
  //info := vk.MemoryGetFdInfoKHR {
  //  sType = .MEMORY_GET_FD_INFO_KHR,
  //  pNext = nil,
  //  memory = buffer.memory,
  //  handleType = { .DMA_BUF_EXT },
  //}

  //fd: i32
  //vk.GetMemoryFdKHR(device, &info, &fd)

  //fmt.println("fd", fd)

}

create_instance :: proc() -> (vk.Instance, bool) {
  instance: vk.Instance

	app_info: vk.ApplicationInfo
	app_info.sType = .APPLICATION_INFO
	app_info.pApplicationName = "Hello Triangle"
	app_info.applicationVersion = vk.MAKE_VERSION(0, 0, 1)
	app_info.pEngineName = "No Engine"
	app_info.engineVersion = vk.MAKE_VERSION(1, 0, 0)
	app_info.apiVersion = vk.API_VERSION_1_4
	
	create_info: vk.InstanceCreateInfo
	create_info.sType = .INSTANCE_CREATE_INFO
	create_info.pApplicationInfo = &app_info

  layer_count: u32
  vk.EnumerateInstanceLayerProperties(&layer_count, nil)
  layers := make([]vk.LayerProperties, layer_count)
  vk.EnumerateInstanceLayerProperties(&layer_count, raw_data(layers))

  check :: proc(v: cstring, availables: []vk.LayerProperties) -> bool {
    for &available in availables do if v == cstring(&available.layerName[0]) do return true

    return false
  }
  
  for name in VALIDATION_LAYERS do if !check(name, layers) do return instance, false
  
  create_info.ppEnabledLayerNames = &VALIDATION_LAYERS[0]
  create_info.enabledLayerCount = len(VALIDATION_LAYERS)
	
	if vk.CreateInstance(&create_info, nil, &instance) != .SUCCESS do return instance, false
	
  fmt.println("Instance Created")
  vk.load_proc_addresses_instance(instance)

  return instance, true
}

checkDeviceExtensionSupport :: proc(physical_device: vk.PhysicalDevice) -> bool {
	ext_count: u32
	vk.EnumerateDeviceExtensionProperties(physical_device, nil, &ext_count, nil)
	
	available_extensions := make([]vk.ExtensionProperties, ext_count)
	vk.EnumerateDeviceExtensionProperties(physical_device, nil, &ext_count, raw_data(available_extensions))

  check_ext :: proc(e: cstring, availables: []vk.ExtensionProperties) -> bool {
    for &available in availables do if e == cstring(&available.extensionName[0]) do return true

    return false
  }

  for ext in DEVICE_EXTENSIONS do if !check_ext(ext, available_extensions) do return false

  mem_info := vk.ExternalMemoryImageCreateInfo {
    sType = .EXTERNAL_MEMORY_IMAGE_CREATE_INFO,
    pNext = nil,
    handleTypes = { .DMA_BUF_EXT },
  }

  info := vk.PhysicalDeviceImageFormatInfo2 {
    sType = .PHYSICAL_DEVICE_IMAGE_FORMAT_INFO_2,
    pNext = &mem_info,
	  format = .B8G8R8A8_UNORM,
    type = .D2,
    tiling = .LINEAR,
    usage = { .TRANSFER_SRC },
    flags = {}
  }

  properties := vk.ImageFormatProperties2 { sType = .IMAGE_FORMAT_PROPERTIES_2 }
  fmt.println(vk.GetPhysicalDeviceImageFormatProperties2(physical_device, &info, &properties))
  fmt.println(properties)

	return true
}

find_physical_device :: proc(instance: vk.Instance) -> (vk.PhysicalDevice, bool) {
  physical_device: vk.PhysicalDevice
	device_count: u32
	
	vk.EnumeratePhysicalDevices(instance, &device_count, nil)

	if device_count == 0 do return physical_device, false

	devices := make([]vk.PhysicalDevice, device_count)
	vk.EnumeratePhysicalDevices(instance, &device_count, raw_data(devices))
	
	suitability :: proc(dev: vk.PhysicalDevice) -> u32 {
		props: vk.PhysicalDeviceProperties
		features: vk.PhysicalDeviceFeatures
		vk.GetPhysicalDeviceProperties(dev, &props)
		vk.GetPhysicalDeviceFeatures(dev, &features)
		
		score: u32 = 0
		if props.deviceType == .DISCRETE_GPU do score += 1000
		if !checkDeviceExtensionSupport(dev) do return 0
		
		return score + props.limits.maxImageDimension2D
	}
	
	hiscore: u32 = 0
	for dev in devices {
		score := suitability(dev)
		if score > hiscore {
			physical_device = dev
			hiscore = score
		}
	}
	
	if hiscore == 0 do return physical_device, false

  return physical_device, true
}

create_device :: proc(physical_device: vk.PhysicalDevice, indices: [2]u32) -> (vk.Device, bool) {
	unique_indices: [10]u32 = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }

	for i in indices do unique_indices[i] += 1
	
	queue_priority := f32(1.0)
	
	queue_create_infos: [dynamic]vk.DeviceQueueCreateInfo
	defer delete(queue_create_infos)

	for k, i in unique_indices {
    if k == 0 do continue
		queue_create_info: vk.DeviceQueueCreateInfo
		queue_create_info.sType = .DEVICE_QUEUE_CREATE_INFO
		queue_create_info.queueFamilyIndex = u32(i)
		queue_create_info.queueCount = 1
		queue_create_info.pQueuePriorities = &queue_priority

		append(&queue_create_infos, queue_create_info)
	}
	
	device_features: vk.PhysicalDeviceFeatures
	device_create_info: vk.DeviceCreateInfo
	device_create_info.sType = .DEVICE_CREATE_INFO
	device_create_info.enabledExtensionCount = u32(len(DEVICE_EXTENSIONS))
	device_create_info.ppEnabledExtensionNames = &DEVICE_EXTENSIONS[0]
	device_create_info.pQueueCreateInfos = raw_data(queue_create_infos)
	device_create_info.queueCreateInfoCount = u32(len(queue_create_infos))
	device_create_info.pEnabledFeatures = &device_features
	device_create_info.enabledLayerCount = 0
	
  device: vk.Device
	if vk.CreateDevice(physical_device, &device_create_info, nil, &device) != .SUCCESS do return device, false

  fmt.println("Device Created")
  vk.load_proc_addresses_device(device)

  return device, true
}

create_queues :: proc(device: vk.Device, queue_indices: [2]u32) -> [2]vk.Queue {
  queues: [2]vk.Queue
  unique_indices: [10]u32 = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }

	for &q, i in &queues {
    indice := queue_indices[i] 
		vk.GetDeviceQueue(device, u32(indice), unique_indices[indice], &q)
    //unique_indices[indice] += 1
	}

  fmt.println("Queues Created")

  return queues
}

find_queue_indices :: proc(physical_device: vk.PhysicalDevice) -> ([2]u32, bool) {
	queue_count: u32
	vk.GetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_count, nil)
	available_queues := make([]vk.QueueFamilyProperties, queue_count)
	vk.GetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_count, raw_data(available_queues))
  MAX: u32 = 0xFF
  indices: [2]u32 = { MAX, MAX }
	
  for v, i in available_queues {
    if .GRAPHICS in v.queueFlags && indices[0] == MAX do indices[0] = u32(i)
    if .TRANSFER in v.queueFlags && indices[1] == MAX do indices[1] = u32(i)
  }

  for indice in indices do if indice == MAX do return indices, false

  return indices, true
}

create_shader_module :: proc(device: vk.Device, code: []u8) -> (vk.ShaderModule, bool) {
	create_info: vk.ShaderModuleCreateInfo
	create_info.sType = .SHADER_MODULE_CREATE_INFO
	create_info.codeSize = len(code)
	create_info.pCode = cast(^u32)raw_data(code)
	
	shader: vk.ShaderModule
	if res := vk.CreateShaderModule(device, &create_info, nil, &shader); res != .SUCCESS do return shader, false
	
	return shader, true
}

create_image :: proc(device: vk.Device, format: vk.Format, type: vk.ImageType, tiling: vk.ImageTiling, usage: vk.ImageUsageFlags, flags: vk.ImageCreateFlags, width: u32, height: u32) -> (vk.Image, bool) {
  mem_info := vk.ExternalMemoryImageCreateInfo {
    sType = .EXTERNAL_MEMORY_IMAGE_CREATE_INFO,
    pNext = nil,
    handleTypes = { .DMA_BUF_EXT },

  }

  info := vk.ImageCreateInfo {
    sType = .IMAGE_CREATE_INFO,
    pNext = &mem_info,
    flags = flags,
    imageType = type,
    format = format,
    mipLevels = 1,
    arrayLayers = 1,
    samples = { ._1 },
    tiling = tiling,
    usage = usage,
    sharingMode = .EXCLUSIVE,
    queueFamilyIndexCount = 0,
    pQueueFamilyIndices = nil,
    initialLayout = .UNDEFINED,
    extent = vk.Extent3D {
      width = width,
      height = height,
      depth = 1,
    },
  }

  image: vk.Image
  if res := vk.CreateImage(device, &info, nil, &image); res != .SUCCESS do return image, false

  fmt.println("Image Created")

  return image, true
}

create_command_pool :: proc(device: vk.Device, queue_index: u32) -> (vk.CommandPool, bool) {
	pool_info: vk.CommandPoolCreateInfo
	pool_info.sType = .COMMAND_POOL_CREATE_INFO
	pool_info.flags = {.RESET_COMMAND_BUFFER}
	pool_info.queueFamilyIndex = queue_index
	
  command_pool: vk.CommandPool
	if res := vk.CreateCommandPool(device, &pool_info, nil, &command_pool); res != .SUCCESS do return command_pool, false

  fmt.println("CommandPool created")

  return command_pool, true
}

allcate_command_buffers :: proc(device: vk.Device, command_pool: vk.CommandPool, count: u32) -> ([]vk.CommandBuffer, bool) {
	alloc_info: vk.CommandBufferAllocateInfo
	alloc_info.sType = .COMMAND_BUFFER_ALLOCATE_INFO
	alloc_info.commandPool = command_pool
	alloc_info.level = .PRIMARY
	alloc_info.commandBufferCount = count
	
  command_buffers := make([]vk.CommandBuffer, count)
	if res := vk.AllocateCommandBuffers(device, &alloc_info, &command_buffers[0]); res != .SUCCESS do return command_buffers, false

  return command_buffers, true
}

find_memory_type :: proc(physical_device: vk.PhysicalDevice, type_filter: u32, properties: vk.MemoryPropertyFlags) -> (u32, bool) {
	mem_properties: vk.PhysicalDeviceMemoryProperties
	vk.GetPhysicalDeviceMemoryProperties(physical_device, &mem_properties)

	for i in 0..<mem_properties.memoryTypeCount {
		if (type_filter & (1 << i) != 0) && (mem_properties.memoryTypes[i].propertyFlags & properties) == properties do return i, true
	}

  return 0, false
}

create_memory :: proc(device: vk.Device, physical_device: vk.PhysicalDevice, requirements: vk.MemoryRequirements, properties: vk.MemoryPropertyFlags) -> (memory: vk.DeviceMemory, ok: bool) {
  export_info := vk.ExportMemoryAllocateInfo {
    sType = .EXPORT_MEMORY_ALLOCATE_INFO,
    pNext = nil,
    handleTypes = { .DMA_BUF_EXT },
  }
	
	alloc_info := vk.MemoryAllocateInfo{
		sType = .MEMORY_ALLOCATE_INFO,
    pNext = &export_info,
		allocationSize = requirements.size,
		memoryTypeIndex = find_memory_type(physical_device, requirements.memoryTypeBits, properties) or_return
	}
	
	if res := vk.AllocateMemory(device, &alloc_info, nil, &memory); res != .SUCCESS do return memory, false

  return memory, true
}

load_fn :: proc(ptr: rawptr, name: cstring) {
    (cast(^rawptr)ptr)^ = dynlib.symbol_address(library, string(name))
}

