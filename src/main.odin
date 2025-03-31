package main

import vk "vendor:vulkan"
import "core:os"
//import "core:fmt"
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
  "VK_EXT_image_drm_format_modifier",
}

VALIDATION_LAYERS := [?]cstring{
  "VK_LAYER_KHRONOS_validation",
}

main :: proc() {
	ctx: Context

  ok: bool
  if library, ok = dynlib.load_library("libvulkan.so"); !ok {
      return
  }

  defer _ = dynlib.unload_library(library)
  vk.load_proc_addresses_custom(load_fn)

  init_vulkan(&ctx)
}

init_vulkan :: proc(ctx: ^Context) -> bool {
  format: vk.Format = .B8G8R8A8_SRGB 

  instance := create_instance() or_return
	defer vk.DestroyInstance(instance, nil)

	physical_device := find_physical_device(instance, { check_physical_device_ext_support }) or_return
  queue_indices := find_queue_indices(physical_device) or_return

  device := create_device(physical_device, queue_indices) or_return
  defer vk.DestroyDevice(device, nil)

  queues := create_queues(device, queue_indices)

  render_pass := create_render_pass(device, format) or_return
  defer vk.DestroyRenderPass(device, render_pass, nil)

  pipeline, layout, set_layouts := create_pipeline(device, render_pass) or_return
  defer vk.DestroyPipeline(device, pipeline, nil)
  defer vk.DestroyPipelineLayout(device, layout, nil)
  defer for set_layout in set_layouts do vk.DestroyDescriptorSetLayout(device, set_layout, nil)

  modifiers_array := make([]u64, 20)
  modifiers := get_drm_modifiers(physical_device, format, modifiers_array)

  image, memory := create_image(device, physical_device, format, .D2, .DRM_FORMAT_MODIFIER_EXT, { .COLOR_ATTACHMENT }, {}, modifiers, 800, 600) or_return
  defer vk.DestroyImage(device, image, nil)
  defer vk.FreeMemory(device, memory, nil)

  return true
}

create_instance :: proc() -> (vk.Instance, bool) {
  layer_count: u32
  vk.EnumerateInstanceLayerProperties(&layer_count, nil)
  layers := make([]vk.LayerProperties, layer_count)
  vk.EnumerateInstanceLayerProperties(&layer_count, raw_data(layers))

  check :: proc(v: cstring, availables: []vk.LayerProperties) -> bool {
    for &available in availables do if v == cstring(&available.layerName[0]) do return true

    return false
  }
  
  instance: vk.Instance
  for name in VALIDATION_LAYERS do if !check(name, layers) do return instance, false
  
	app_info := vk.ApplicationInfo {
    sType = .APPLICATION_INFO,
    pApplicationName = "Hello Triangle",
    applicationVersion = vk.MAKE_VERSION(0, 0, 1),
    pEngineName = "No Engine",
    engineVersion = vk.MAKE_VERSION(0, 0, 1),
    apiVersion = vk.API_VERSION_1_4,
  }

	create_info := vk.InstanceCreateInfo {
    sType = .INSTANCE_CREATE_INFO,
    pApplicationInfo = &app_info,
    ppEnabledLayerNames = &VALIDATION_LAYERS[0],
    enabledLayerCount = len(VALIDATION_LAYERS),
  }
	
	if vk.CreateInstance(&create_info, nil, &instance) != .SUCCESS do return instance, false
	
  vk.load_proc_addresses_instance(instance)

  return instance, true
}

create_device :: proc(physical_device: vk.PhysicalDevice, indices: [2]u32) -> (vk.Device, bool) {
	queue_priority := f32(1.0)

	unique_indices: [10]u32 = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
	for i in indices do unique_indices[i] += 1

	queue_create_infos: [dynamic]vk.DeviceQueueCreateInfo
	defer delete(queue_create_infos)

	for k, i in unique_indices {
    if k == 0 do continue

		queue_create_info := vk.DeviceQueueCreateInfo {
      sType = .DEVICE_QUEUE_CREATE_INFO,
      queueFamilyIndex = u32(i),
      queueCount = 1,
      pQueuePriorities = &queue_priority,
    }

		append(&queue_create_infos, queue_create_info)
	}

  feature_info := vk.PhysicalDeviceVulkan13Features {
    sType = .PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
    synchronization2 = true
  }
	
	device_create_info := vk.DeviceCreateInfo {
    sType = .DEVICE_CREATE_INFO,
    pNext = &feature_info,
    enabledExtensionCount = u32(len(DEVICE_EXTENSIONS)),
    ppEnabledExtensionNames = &DEVICE_EXTENSIONS[0],
    pQueueCreateInfos = &queue_create_infos[0],
    queueCreateInfoCount = u32(len(queue_create_infos)),
    pEnabledFeatures = nil,
    enabledLayerCount = 0,
  }

  device: vk.Device
	if vk.CreateDevice(physical_device, &device_create_info, nil, &device) != .SUCCESS do return device, false

  vk.load_proc_addresses_device(device)

  return device, true
}

create_pipeline :: proc(device: vk.Device, render_pass: vk.RenderPass) -> (pipeline: vk.Pipeline, layout: vk.PipelineLayout, set_layouts: [1]vk.DescriptorSetLayout, ok: bool) {
  vert_code := os.read_entire_file("assets/output/vert.spv") or_return
  frag_code := os.read_entire_file("assets/output/frag.spv") or_return

  vert_module_info := vk.ShaderModuleCreateInfo {
    sType = .SHADER_MODULE_CREATE_INFO,
    codeSize = len(vert_code),
    pCode = cast([^]u32)(&vert_code[0])
  }

  frag_module_info := vk.ShaderModuleCreateInfo {
    sType = .SHADER_MODULE_CREATE_INFO,
    codeSize = len(frag_code),
    pCode = cast([^]u32)(&frag_code[0])
  }

  vert_module: vk.ShaderModule
  if vk.CreateShaderModule(device, &vert_module_info, nil, &vert_module) != .SUCCESS do return pipeline, layout, set_layouts, false
  defer vk.DestroyShaderModule(device, vert_module, nil)

  frag_module: vk.ShaderModule
  if vk.CreateShaderModule(device, &frag_module_info, nil, &frag_module) != .SUCCESS do return pipeline, layout, set_layouts, false
  defer vk.DestroyShaderModule(device, frag_module, nil)

  stages := [?]vk.PipelineShaderStageCreateInfo {
    {
      sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
      stage = { .VERTEX },
      module = vert_module,
      pName = cstring("main"),
    },
    {
      sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
      stage = { .FRAGMENT },
      module = frag_module,
      pName = cstring("main"),
    },
  }

  vertex_binding_descriptions := [?]vk.VertexInputBindingDescription {
    {
      binding = 0,
      stride = size_of(f32) * 5,
      inputRate = .VERTEX,
    }
  }

  vertex_attribute_descriptions := [?]vk.VertexInputAttributeDescription {
    {
      location = 0,
      binding = 0,
      offset = 0,
      format = .R32G32_SFLOAT,
    },
    {
      location = 1,
      binding = 0,
      offset = size_of(f32) * 2,
      format = .R32G32B32_SFLOAT,
    }
  }

  vert_input_state := vk.PipelineVertexInputStateCreateInfo {
    sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
    vertexBindingDescriptionCount = u32(len(vertex_binding_descriptions)),
    pVertexBindingDescriptions = &vertex_binding_descriptions[0],
    vertexAttributeDescriptionCount = u32(len(vertex_attribute_descriptions)),
    pVertexAttributeDescriptions = &vertex_attribute_descriptions[0],
  }

  viewports := [?]vk.Viewport {
    {
      x = 0,
      y = 0,
      width = 200,
      height = 200,
      minDepth = 0,
      maxDepth = 1,
    }
  }

  scissors := [?]vk.Rect2D {
    {
      offset = vk.Offset2D {
        x = 0,
        y = 0,
      },
      extent = vk.Extent2D {
        width = 200,
        height = 200,
      }
    }
  }

  viewport_state := vk.PipelineViewportStateCreateInfo {
    sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
    viewportCount = u32(len(viewports)),
    pViewports = &viewports[0],
    scissorCount = u32(len(scissors)),
    pScissors = &scissors[0],
  }

  multisample_state := vk.PipelineMultisampleStateCreateInfo {
    sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
    rasterizationSamples = {._1 },
    sampleShadingEnable = false,
    alphaToOneEnable = false,
    alphaToCoverageEnable = false,
    minSampleShading = 1.0,
  }

  depth_stencil_stage := vk.PipelineDepthStencilStateCreateInfo {
    sType = .PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
    depthTestEnable = false,
    depthWriteEnable = false,
    depthCompareOp = .LESS,
    depthBoundsTestEnable = false,
    stencilTestEnable = false,
    minDepthBounds = 0.0,
    maxDepthBounds = 1.0,
  }

  color_blend_attachments := [?]vk.PipelineColorBlendAttachmentState {
    {
      blendEnable = false,
      srcColorBlendFactor = .ONE,
      dstColorBlendFactor = .ZERO,
      colorBlendOp = .ADD,
      srcAlphaBlendFactor = .ONE,
      dstAlphaBlendFactor = .ZERO,
      alphaBlendOp = .ADD,
      colorWriteMask = { .R, .G, .B, .A },
    }
  }

  color_blend_state := vk.PipelineColorBlendStateCreateInfo {
    sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
    logicOpEnable = false,
    attachmentCount = u32(len(color_blend_attachments)),
    pAttachments = &color_blend_attachments[0],
    blendConstants = { 0, 0, 0, 0 },
  }

  rasterization_state := vk.PipelineRasterizationStateCreateInfo {
    sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
    depthClampEnable = false,
    rasterizerDiscardEnable = false,
    polygonMode = .FILL,
    cullMode = { .FRONT },
    frontFace = .CLOCKWISE,
    depthBiasEnable = false,
    depthBiasClamp = 0.0,
    depthBiasConstantFactor = 0.0,
    depthBiasSlopeFactor = 0.0,
    lineWidth = 1,
  }

  input_assembly_state := vk.PipelineInputAssemblyStateCreateInfo {
    sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
    topology = .TRIANGLE_FAN,
  }

  dynamic_states := [?]vk.DynamicState { .VIEWPORT, .SCISSOR }

  dynamic_state := vk.PipelineDynamicStateCreateInfo {
    sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
    dynamicStateCount = u32(len(dynamic_states)),
    pDynamicStates = &dynamic_states[0],
  }

  set_layout_bindings := [?]vk.DescriptorSetLayoutBinding {
    {
      binding = 0,
      stageFlags = { .VERTEX },
      descriptorType = .UNIFORM_BUFFER,
      descriptorCount = 1,
    }
  }

  set_layout_infos := [?]vk.DescriptorSetLayoutCreateInfo {
    {
      sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
      bindingCount = u32(len(set_layout_bindings)),
      pBindings = &set_layout_bindings[0],
    }
  }

  for i in 0..<len(set_layouts) {
    if vk.CreateDescriptorSetLayout(device, &set_layout_infos[i], nil, &set_layouts[i]) != .SUCCESS do return pipeline, layout, set_layouts, false
  }

  layout_info := vk.PipelineLayoutCreateInfo {
    sType = .PIPELINE_LAYOUT_CREATE_INFO,
    setLayoutCount = u32(len(set_layouts)),
    pSetLayouts = &set_layouts[0],
  }
  
  if vk.CreatePipelineLayout(device, &layout_info, nil, &layout) != .SUCCESS do return pipeline, layout, set_layouts, false

  info := vk.GraphicsPipelineCreateInfo {
    sType = .GRAPHICS_PIPELINE_CREATE_INFO,
    stageCount = u32(len(stages)),
    pStages = &stages[0],
    pViewportState = &viewport_state,
    pVertexInputState = &vert_input_state,
    pMultisampleState = &multisample_state,
    pDepthStencilState = &depth_stencil_stage,
    pColorBlendState = &color_blend_state,
    pRasterizationState = &rasterization_state,
    pInputAssemblyState = &input_assembly_state,
    pDynamicState = &dynamic_state,
    renderPass = render_pass,
    layout = layout,
  }

  if vk.CreateGraphicsPipelines(device, 0, 1, &info, nil, &pipeline) != .SUCCESS do return pipeline, layout, set_layouts, false

  return pipeline, layout, set_layouts, true
}

create_render_pass :: proc(device: vk.Device, format: vk.Format) -> (vk.RenderPass, bool) {
  render_pass_attachments := [?]vk.AttachmentDescription {
    {
      format = format,
      samples = { ._1 },
      loadOp = .CLEAR,
      storeOp = .STORE,
      initialLayout = .GENERAL,
      finalLayout = .GENERAL,
      stencilLoadOp = .DONT_CARE,
      stencilStoreOp = .DONT_CARE,
    }
  }

  subpass_color_attachments := [?]vk.AttachmentReference {
    {
      attachment = 0,
      layout = .ATTACHMENT_OPTIMAL,
    }
  }

  render_pass_subpass := [?]vk.SubpassDescription {
    {
      pipelineBindPoint = .GRAPHICS,
      colorAttachmentCount = u32(len(subpass_color_attachments)),
      pColorAttachments = &subpass_color_attachments[0],
      pDepthStencilAttachment = nil,
    }
  }

  render_pass_dependencies := [?]vk.SubpassDependency {
    {
      srcSubpass = 0,
      dstSubpass = vk.SUBPASS_EXTERNAL,
      srcAccessMask = { .COLOR_ATTACHMENT_WRITE },
      dstAccessMask = { .TRANSFER_READ },
      srcStageMask = { .COLOR_ATTACHMENT_OUTPUT },
      dstStageMask = { .TRANSFER, .HOST },
    }
  }

  render_pass_info := vk.RenderPassCreateInfo {
    sType = .RENDER_PASS_CREATE_INFO, 
    attachmentCount = u32(len(render_pass_attachments)),
    pAttachments = &render_pass_attachments[0],
    subpassCount = u32(len(render_pass_subpass)),
    pSubpasses = &render_pass_subpass[0],
    dependencyCount = u32(len(render_pass_dependencies)),
    pDependencies = &render_pass_dependencies[0],
  }

  render_pass: vk.RenderPass
  if vk.CreateRenderPass(device, &render_pass_info, nil, &render_pass) != .SUCCESS do return render_pass, false

  return render_pass, true
}

get_drm_modifiers :: proc(physical_device: vk.PhysicalDevice, format: vk.Format, modifiers: []u64) -> []u64 {
  l: u32 = 0
  render_features: vk.FormatFeatureFlags = { .COLOR_ATTACHMENT, .COLOR_ATTACHMENT_BLEND }
  texture_features: vk.FormatFeatureFlags = { .SAMPLED_IMAGE, .SAMPLED_IMAGE_FILTER_LINEAR }

  modifier_properties_list := vk.DrmFormatModifierPropertiesListEXT {
    sType = .DRM_FORMAT_MODIFIER_PROPERTIES_LIST_EXT,
  }

  properties := vk.FormatProperties2 {
    sType = .FORMAT_PROPERTIES_2,
    pNext = &modifier_properties_list,
  }

  vk.GetPhysicalDeviceFormatProperties2(physical_device, format, &properties)
  count := modifier_properties_list.drmFormatModifierCount

  drmFormatModifierProperties := make([]vk.DrmFormatModifierPropertiesEXT, count)
  modifier_properties_list.pDrmFormatModifierProperties = &drmFormatModifierProperties[0]

  vk.GetPhysicalDeviceFormatProperties2(physical_device, format, &properties)

  image_modifier_info := vk.PhysicalDeviceImageDrmFormatModifierInfoEXT {
    sType = .PHYSICAL_DEVICE_IMAGE_DRM_FORMAT_MODIFIER_INFO_EXT,
    sharingMode = .EXCLUSIVE,
  }

  external_image_info := vk.PhysicalDeviceExternalImageFormatInfo {
    sType = .PHYSICAL_DEVICE_EXTERNAL_IMAGE_FORMAT_INFO,
    pNext = &image_modifier_info,
    handleType = { .DMA_BUF_EXT },
  }

  image_info := vk.PhysicalDeviceImageFormatInfo2 {
    sType = .PHYSICAL_DEVICE_IMAGE_FORMAT_INFO_2,
    pNext = &external_image_info,
    format = format,
    type = .D2,
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

  for i in 0..<count {
    modifier_properties := modifier_properties_list.pDrmFormatModifierProperties[i]
    image_modifier_info.drmFormatModifier = modifier_properties.drmFormatModifier

    if modifier_properties.drmFormatModifierTilingFeatures < render_features do continue
    if modifier_properties.drmFormatModifierTilingFeatures < texture_features do continue

    image_info.usage = { .COLOR_ATTACHMENT }

    if vk.GetPhysicalDeviceImageFormatProperties2(physical_device, &image_info, &image_properties) != .SUCCESS do continue
    if emp.externalMemoryFeatures < { .IMPORTABLE, .EXPORTABLE } do continue

    image_info.usage = { .SAMPLED }

    if vk.GetPhysicalDeviceImageFormatProperties2(physical_device, &image_info, &image_properties) != .SUCCESS do continue
    if emp.externalMemoryFeatures < { .IMPORTABLE, .EXPORTABLE } do continue

    modifiers[l] = modifier_properties.drmFormatModifier
    l += 1
  }

  return modifiers[0:l]
}

check_physical_device_ext_support :: proc(physical_device: vk.PhysicalDevice) -> bool {
	count: u32

	vk.EnumerateDeviceExtensionProperties(physical_device, nil, &count, nil)
	available_extensions := make([]vk.ExtensionProperties, count)
	vk.EnumerateDeviceExtensionProperties(physical_device, nil, &count, &available_extensions[0])

  check :: proc(e: cstring, availables: []vk.ExtensionProperties) -> bool {
    for &available in availables do if e == cstring(&available.extensionName[0]) do return true

    return false
  }

  for ext in DEVICE_EXTENSIONS do if !check(ext, available_extensions) do return false
  
	return true
}

find_physical_device :: proc(instance: vk.Instance, checks: []proc(vk.PhysicalDevice) -> bool) -> (vk.PhysicalDevice, bool) {
  physical_device: vk.PhysicalDevice
	device_count: u32
	
	vk.EnumeratePhysicalDevices(instance, &device_count, nil)

	if device_count == 0 do return physical_device, false

	devices := make([]vk.PhysicalDevice, device_count)
	vk.EnumeratePhysicalDevices(instance, &device_count, raw_data(devices))
	
	suitability :: proc(dev: vk.PhysicalDevice, checks: []proc(vk.PhysicalDevice) -> bool) -> u32 {
		props: vk.PhysicalDeviceProperties
		features: vk.PhysicalDeviceFeatures

		vk.GetPhysicalDeviceProperties(dev, &props)
		vk.GetPhysicalDeviceFeatures(dev, &features)
		
		score: u32 = 10
		if props.deviceType == .DISCRETE_GPU do score += 1000

    for check in checks do if !check(dev) do return 0

		return score + props.limits.maxImageDimension2D
	}
	
	hiscore: u32 = 0
	for dev in devices {
		score := suitability(dev, checks)
		if score > hiscore {
			physical_device = dev
			hiscore = score
		}
	}
	
	if hiscore == 0 do return physical_device, false

  return physical_device, true
}

create_queues :: proc(device: vk.Device, queue_indices: [2]u32) -> [2]vk.Queue {
  queues: [2]vk.Queue

	for &q, i in &queues {
		vk.GetDeviceQueue(device, u32(queue_indices[i]), 0, &q)
	}

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

  for indice in indices {
    if indice == MAX do return indices, false
  }

  return indices, true
}

create_image :: proc(device: vk.Device, physical_device: vk.PhysicalDevice, format: vk.Format, type: vk.ImageType, tiling: vk.ImageTiling, usage: vk.ImageUsageFlags, flags: vk.ImageCreateFlags, modifiers: []u64, width: u32, height: u32) -> (image: vk.Image, memory: vk.DeviceMemory, ok: bool) {

  list_info := vk.ImageDrmFormatModifierListCreateInfoEXT {
    sType = .IMAGE_DRM_FORMAT_MODIFIER_LIST_CREATE_INFO_EXT,
    pNext = nil,
    drmFormatModifierCount = u32(len(modifiers)),
    pDrmFormatModifiers = &modifiers[0],
  }

  info := vk.ImageCreateInfo {
    sType = .IMAGE_CREATE_INFO,
    pNext = &list_info,
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

  if res := vk.CreateImage(device, &info, nil, &image); res != .SUCCESS {
    return image, memory, false
  }

  requirements: vk.MemoryRequirements
  vk.GetImageMemoryRequirements(device, image, &requirements)

  import_info := vk.ExportMemoryAllocateInfo {
    sType = .EXPORT_MEMORY_ALLOCATE_INFO,
    pNext = nil,
    handleTypes = { .DMA_BUF_EXT },
  }

  memory = create_memory(device, physical_device, requirements, { .HOST_VISIBLE, .HOST_COHERENT }, nil) or_return

  vk.BindImageMemory(device, image, memory, vk.DeviceSize(0))

  return image, memory, true
}

create_command_pool :: proc(device: vk.Device, queue_index: u32) -> (vk.CommandPool, bool) {
	pool_info: vk.CommandPoolCreateInfo
	pool_info.sType = .COMMAND_POOL_CREATE_INFO
	pool_info.flags = {.RESET_COMMAND_BUFFER}
	pool_info.queueFamilyIndex = queue_index
	
  command_pool: vk.CommandPool
	if res := vk.CreateCommandPool(device, &pool_info, nil, &command_pool); res != .SUCCESS do return command_pool, false

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

create_shader_module :: proc(device: vk.Device, code: []u8) -> (vk.ShaderModule, bool) {
	create_info := vk.ShaderModuleCreateInfo {
    sType = .SHADER_MODULE_CREATE_INFO,
    codeSize = len(code),
    pCode = cast(^u32)raw_data(code),
  }
	
	shader: vk.ShaderModule
	if res := vk.CreateShaderModule(device, &create_info, nil, &shader); res != .SUCCESS do return shader, false
	
	return shader, true
}

find_memory_type :: proc(physical_device: vk.PhysicalDevice, type_filter: u32, properties: vk.MemoryPropertyFlags) -> (u32, bool) {
	mem_properties: vk.PhysicalDeviceMemoryProperties
	vk.GetPhysicalDeviceMemoryProperties(physical_device, &mem_properties)

	for i in 0..<mem_properties.memoryTypeCount {
		if (type_filter & (1 << i) != 0) && (mem_properties.memoryTypes[i].propertyFlags & properties) == properties do return i, true
	}

  return 0, false
}

create_buffer :: proc(device: vk.Device, physical_device: vk.PhysicalDevice, size: vk.DeviceSize, usage: vk.BufferUsageFlags, properties: vk.MemoryPropertyFlags) -> (buffer: vk.Buffer, memory: vk.DeviceMemory, ok: bool) {
  buf_mem_info := vk.ExternalMemoryBufferCreateInfo {
    sType = .EXTERNAL_MEMORY_BUFFER_CREATE_INFO,
    pNext = nil,
    handleTypes = { .DMA_BUF_EXT },
  }

  buf_info := vk.BufferCreateInfo {
    sType = .BUFFER_CREATE_INFO,
    pNext = &buf_mem_info,
    size = size,
    usage = usage,
    flags = {},
    sharingMode = .EXCLUSIVE,
  }

  if vk.CreateBuffer(device, &buf_info, nil, &buffer) != .SUCCESS do return buffer, memory, false

  requirements: vk.MemoryRequirements
  vk.GetBufferMemoryRequirements(device, buffer, &requirements)

  ded_info := vk.MemoryDedicatedAllocateInfo {
    sType = .MEMORY_DEDICATED_ALLOCATE_INFO,
    buffer = buffer
  }

  export_info := vk.ExportMemoryAllocateInfo {
    sType = .EXPORT_MEMORY_ALLOCATE_INFO,
    pNext = &ded_info,
    handleTypes = { .DMA_BUF_EXT },
  }

  memory = create_memory(device, physical_device, requirements, properties, &export_info) or_return

  vk.BindBufferMemory(device, buffer, memory, 0)

  return buffer, memory, true
}

create_memory :: proc(device: vk.Device, physical_device: vk.PhysicalDevice, requirements: vk.MemoryRequirements, properties: vk.MemoryPropertyFlags, pNext: rawptr) -> (memory: vk.DeviceMemory, ok: bool) {
	alloc_info := vk.MemoryAllocateInfo{
		sType = .MEMORY_ALLOCATE_INFO,
    pNext = pNext,
		allocationSize = requirements.size,
		memoryTypeIndex = find_memory_type(physical_device, requirements.memoryTypeBits, properties) or_return
	}
	
	if res := vk.AllocateMemory(device, &alloc_info, nil, &memory); res != .SUCCESS do return memory, false

  return memory, true
}

load_fn :: proc(ptr: rawptr, name: cstring) {
    (cast(^rawptr)ptr)^ = dynlib.symbol_address(library, string(name))
}

