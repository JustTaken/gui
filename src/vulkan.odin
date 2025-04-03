package main

import vk "vendor:vulkan"
import "core:dynlib"
import "base:runtime"
import "core:os"
import "core:mem"
import "core:fmt"

library: dynlib.Library

VALIDATION_LAYERS := [?]cstring{
  "VK_LAYER_KHRONOS_validation",
}

DEVICE_EXTENSIONS := [?]cstring{
  "VK_KHR_external_memory_fd",
  "VK_EXT_external_memory_dma_buf",
  "VK_EXT_image_drm_format_modifier",
}

Vertex :: struct {
  position: [2]f32,
}

VulkanContext :: struct {
  instance: vk.Instance,
  device: vk.Device,
  physical_device: vk.PhysicalDevice,
  queues: []vk.Queue,
  queue_indices: [2]u32,
  set_layouts: []vk.DescriptorSetLayout,
  layout: vk.PipelineLayout,
  pipeline: vk.Pipeline,
  render_pass: vk.RenderPass,
  command_pool: vk.CommandPool,
  command_buffers: []vk.CommandBuffer,

  uniform_buffer: vk.Buffer,
  uniform_buffer_memory: vk.DeviceMemory,
  descriptor_pool: vk.DescriptorPool,
  descriptor_sets: []vk.DescriptorSet,

  image: vk.Image,
  memory: vk.DeviceMemory,
  image_view: vk.ImageView,

  framebuffer: vk.Framebuffer,

  vertex_buffer: vk.Buffer,
  vertex_buffer_memory: vk.DeviceMemory,

  fence: vk.Fence,
  semaphore: vk.Semaphore,

  width: u32,
  height: u32,
  format: vk.Format,

  modifiers: []u64,

  arena: ^mem.Arena,
  allocator: runtime.Allocator,

  tmp_arena: ^mem.Arena,
  tmp_allocator: runtime.Allocator,
}

init_vulkan :: proc(ctx: ^VulkanContext, width: u32, height: u32, arena: ^mem.Arena, tmp_arena: ^mem.Arena) -> bool {
  {
    ok: bool
    if library, ok = dynlib.load_library("libvulkan.so"); !ok do return false
    vk.load_proc_addresses_custom(load_fn)
  }

  ctx.arena = arena
  ctx.tmp_arena = tmp_arena
  ctx.allocator = mem.arena_allocator(arena)
  ctx.tmp_allocator = mem.arena_allocator(tmp_arena)

  ctx.format = .B8G8R8A8_SRGB 
  ctx.width = width
  ctx.height = height

  mark := mem.begin_arena_temp_memory(ctx.tmp_arena)
  defer mem.end_arena_temp_memory(mark)

  ctx.instance = create_instance(ctx.tmp_allocator) or_return
  ctx.physical_device = find_physical_device(ctx.instance, ctx.tmp_allocator) or_return
  ctx.modifiers = get_drm_modifiers(ctx.physical_device, ctx.format, ctx.allocator)
  ctx.queue_indices = find_queue_indices(ctx.physical_device, ctx.tmp_allocator) or_return
  ctx.device = create_device(ctx.physical_device, ctx.queue_indices[:], ctx.tmp_allocator) or_return
  ctx.render_pass = create_render_pass(ctx.device, ctx.format) or_return
  ctx.set_layouts = create_set_layouts(ctx.device, ctx.allocator) or_return
  ctx.uniform_buffer = create_buffer(ctx.device, size_of([3]f32), { .UNIFORM_BUFFER }) or_return
  ctx.uniform_buffer_memory = create_buffer_memory(ctx.device, ctx.physical_device, ctx.uniform_buffer, { .HOST_COHERENT, .HOST_VISIBLE }) or_return
  ctx.descriptor_pool = create_descriptor_pool(ctx.device) or_return
  ctx.descriptor_sets = allocate_descriptor_sets(ctx.device, ctx.set_layouts, ctx.descriptor_pool, ctx.uniform_buffer, 0, ctx.allocator) or_return
  ctx.layout = create_layout(ctx.device, ctx.set_layouts) or_return
  ctx.pipeline = create_pipeline(ctx.device, ctx.layout, ctx.render_pass, ctx.width, ctx.height, ctx.tmp_allocator) or_return
  ctx.queues = create_queues(ctx.device, ctx.queue_indices[:], ctx.allocator) or_return
  ctx.command_pool = create_command_pool(ctx.device, ctx.queue_indices[1]) or_return
  ctx.command_buffers = allocate_command_buffers(ctx.device, ctx.command_pool, 1, ctx.allocator) or_return

  init_frame(ctx) or_return

  ctx.fence = create_fence(ctx.device) or_return
  ctx.semaphore = create_semaphore(ctx.device) or_return

  vertices := [?]Vertex {
    { position = { -1.0, -1.0 } },
    { position = { -1.0, -0.5 } },
    { position = { -0.5, -1.0 } },

    { position = {  1.0, -1.0 } },
    { position = {  0.0, 1.0 } },
    { position = {  1.0, 1.0 } },
  }

  ctx.vertex_buffer = create_buffer(ctx.device, size_of(Vertex) * len(vertices), { .VERTEX_BUFFER }) or_return
  ctx.vertex_buffer_memory = create_buffer_memory(ctx.device, ctx.physical_device, ctx.vertex_buffer, { .HOST_COHERENT, .HOST_VISIBLE, .DEVICE_LOCAL }) or_return

  copy_data(Vertex, ctx.device, ctx.vertex_buffer_memory, vertices[:])

  return true
}

deinit_vulkan :: proc(ctx: ^VulkanContext) {
  vk.DestroyBuffer(ctx.device, ctx.uniform_buffer, nil)
  vk.FreeMemory(ctx.device, ctx.uniform_buffer_memory, nil)
  vk.DestroyBuffer(ctx.device, ctx.vertex_buffer, nil)
  vk.FreeMemory(ctx.device, ctx.vertex_buffer_memory, nil)
  vk.DestroySemaphore(ctx.device, ctx.semaphore, nil)
  vk.DestroyFence(ctx.device, ctx.fence, nil)
  vk.DestroyFramebuffer(ctx.device, ctx.framebuffer, nil)
  vk.DestroyImageView(ctx.device, ctx.image_view, nil)
  vk.FreeMemory(ctx.device, ctx.memory, nil)
  vk.DestroyImage(ctx.device, ctx.image, nil)
  vk.DestroyCommandPool(ctx.device, ctx.command_pool, nil)
  vk.DestroyDescriptorPool(ctx.device, ctx.descriptor_pool, nil)
  vk.DestroyPipeline(ctx.device, ctx.pipeline, nil)
  vk.DestroyPipelineLayout(ctx.device, ctx.layout, nil)

  for set_layout in ctx.set_layouts {
    vk.DestroyDescriptorSetLayout(ctx.device, set_layout, nil)
  }

  vk.DestroyRenderPass(ctx.device, ctx.render_pass, nil)
  vk.DestroyDevice(ctx.device, nil)
  vk.DestroyInstance(ctx.instance, nil)

   _ = dynlib.unload_library(library)
}

init_frame :: proc(ctx: ^VulkanContext) -> bool {
  mem_info := vk.ExternalMemoryImageCreateInfo {
    sType = .EXTERNAL_MEMORY_IMAGE_CREATE_INFO,
    handleTypes = { .DMA_BUF_EXT },
  }

  list_info := vk.ImageDrmFormatModifierListCreateInfoEXT {
    sType = .IMAGE_DRM_FORMAT_MODIFIER_LIST_CREATE_INFO_EXT,
    pNext = &mem_info,
    drmFormatModifierCount = u32(len(ctx.modifiers)),
    pDrmFormatModifiers = &ctx.modifiers[0],
  }

  import_info := vk.ExportMemoryAllocateInfo {
    sType = .EXPORT_MEMORY_ALLOCATE_INFO,
    pNext = nil,
    handleTypes = { .DMA_BUF_EXT },
  }

  ctx.image = create_image(ctx.device, ctx.format, .D2, .DRM_FORMAT_MODIFIER_EXT, { .COLOR_ATTACHMENT, .TRANSFER_SRC}, {  }, &list_info, ctx.modifiers, ctx.width, ctx.height) or_return
  ctx.memory = create_image_memory(ctx.device, ctx.physical_device, ctx.image, &import_info) or_return
  ctx.image_view = create_image_view(ctx.device, ctx.image, ctx.format) or_return
  ctx.framebuffer = create_framebuffer(ctx.device, ctx.render_pass, &ctx.image_view, ctx.width, ctx.height) or_return

  return true
}

resize_renderer :: proc(ctx: ^VulkanContext, width: u32, height: u32) -> bool {
  ctx.width = width
  ctx.height = height

  vk.DestroyFramebuffer(ctx.device, ctx.framebuffer, nil)
  vk.DestroyImageView(ctx.device, ctx.image_view, nil)
  vk.FreeMemory(ctx.device, ctx.memory, nil)
  vk.DestroyImage(ctx.device, ctx.image, nil)

  init_frame(ctx) or_return
  draw(ctx) or_return

  return true
}

draw :: proc(ctx: ^VulkanContext) -> bool {
  cmd := ctx.command_buffers[0]

  vertex_buffers := [?]vk.Buffer{ ctx.vertex_buffer }
  vertex_offsets := [?]vk.DeviceSize{ 0 * size_of(Vertex) }

  area := vk.Rect2D {
    offset = vk.Offset2D {
      x = 0,
      y = 0,
    },

    extent = vk.Extent2D {
      width = ctx.width,
      height = ctx.height,
    }
  }

  clear_values := [?]vk.ClearValue {
    {
      color = vk.ClearColorValue {
        float32 = { 1, 0, 0, 1 },
      }
    }
  }

  viewport := vk.Viewport  {
    width = f32(ctx.width),
    height = f32(ctx.height),
    minDepth = 0,
    maxDepth = 1,
  }

  begin_info := vk.CommandBufferBeginInfo {
    sType = .COMMAND_BUFFER_BEGIN_INFO,
    flags = { .ONE_TIME_SUBMIT },
  }

  render_pass_info := vk.RenderPassBeginInfo {
    sType = .RENDER_PASS_BEGIN_INFO,
    renderPass = ctx.render_pass,
    framebuffer = ctx.framebuffer,
    renderArea = area, 
    clearValueCount = u32(len(clear_values)),
    pClearValues = &clear_values[0],
  }

  if vk.BeginCommandBuffer(cmd, &begin_info) != .SUCCESS do return false

  vk.CmdBeginRenderPass(cmd, &render_pass_info, .INLINE)
  vk.CmdBindPipeline(cmd, .GRAPHICS, ctx.pipeline)
  vk.CmdSetViewport(cmd, 0, 1, &viewport)
  vk.CmdSetScissor(cmd, 0, 1, &area)
  vk.CmdBindVertexBuffers(cmd, 0, u32(len(vertex_buffers)), &vertex_buffers[0], &vertex_offsets[0])
  //vk.CmdBindDescriptorSets(cmd, .GRAPHICS, ctx.layout, 0, u32(len(ctx.descriptor_sets)), &ctx.descriptor_sets[0], 0, nil)
  vk.CmdDraw(cmd, 6, 1, 0, 0)
  vk.CmdEndRenderPass(cmd)

  if vk.EndCommandBuffer(cmd) != .SUCCESS do return false

  wait_stage := vk.PipelineStageFlags { .COLOR_ATTACHMENT_OUTPUT }

  submit_info := vk.SubmitInfo {
    sType = .SUBMIT_INFO,
    commandBufferCount = 1,
    pCommandBuffers = &cmd,
    pWaitDstStageMask = &wait_stage,
    //signalSemaphoreCount = 1,
    //pSignalSemaphores = &ctx.semaphore,
  }

  vk.ResetFences(ctx.device, 1, &ctx.fence)
  if vk.QueueSubmit(ctx.queues[0], 1, &submit_info, ctx.fence) != .SUCCESS do return false
  if vk.WaitForFences(ctx.device, 1, &ctx.fence, true, 0xFFFFFF) != .SUCCESS do return false

  return true
}

create_instance :: proc(allocator: runtime.Allocator) -> (vk.Instance, bool) {
  instance: vk.Instance
  err: mem.Allocator_Error
  layers: []vk.LayerProperties

  layer_count: u32
  vk.EnumerateInstanceLayerProperties(&layer_count, nil)
  if layers, err = make([]vk.LayerProperties, layer_count, allocator); err != nil do return instance, false
  vk.EnumerateInstanceLayerProperties(&layer_count, &layers[0])

  check :: proc(v: cstring, availables: []vk.LayerProperties) -> bool {
    for &available in availables do if v == cstring(&available.layerName[0]) do return true

    return false
  }

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

create_device :: proc(physical_device: vk.PhysicalDevice, indices: []u32, allocator: runtime.Allocator) -> (vk.Device, bool) {
  queue_priority := f32(1.0)

  unique_indices: [10]u32 = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
  for i in indices do unique_indices[i] += 1

  queue_create_infos := make([dynamic]vk.DeviceQueueCreateInfo, 0, len(indices), allocator)
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

create_set_layouts :: proc(device: vk.Device, allocator: runtime.Allocator) -> ([]vk.DescriptorSetLayout, bool) {
  set_layouts: []vk.DescriptorSetLayout = make([]vk.DescriptorSetLayout, 1, allocator)

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
    if vk.CreateDescriptorSetLayout(device, &set_layout_infos[i], nil, &set_layouts[i]) != .SUCCESS do return set_layouts, false
  }

  return set_layouts, true
}

create_layout :: proc(device: vk.Device, set_layouts: []vk.DescriptorSetLayout) -> (vk.PipelineLayout, bool) {
  layout_info := vk.PipelineLayoutCreateInfo {
    sType = .PIPELINE_LAYOUT_CREATE_INFO,
    setLayoutCount = u32(len(set_layouts)),
    pSetLayouts = &set_layouts[0],
  }
  
  layout: vk.PipelineLayout
  if vk.CreatePipelineLayout(device, &layout_info, nil, &layout) != .SUCCESS do return layout, false

  return layout, true
}

create_pipeline :: proc(device: vk.Device, layout: vk.PipelineLayout, render_pass: vk.RenderPass, width: u32, height: u32, allocator: runtime.Allocator) -> (pipeline: vk.Pipeline, ok: bool) {
  vert_module := create_shader_module(device, "assets/output/vert.spv", allocator) or_return
  defer vk.DestroyShaderModule(device, vert_module, nil)

  frag_module := create_shader_module(device, "assets/output/frag.spv", allocator) or_return
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
      stride = size_of(Vertex),
      inputRate = .VERTEX,
    }
  }

  vertex_attribute_descriptions := [?]vk.VertexInputAttributeDescription {
    {
      location = 0,
      binding = 0,
      offset = 0,
      format = .R32G32B32_SFLOAT,
    },
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
      width = f32(width),
      height = f32(height),
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
        width = height,
        height = height,
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
    topology = .TRIANGLE_LIST,
  }

  dynamic_states := [?]vk.DynamicState { .VIEWPORT, .SCISSOR }

  dynamic_state := vk.PipelineDynamicStateCreateInfo {
    sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
    dynamicStateCount = u32(len(dynamic_states)),
    pDynamicStates = &dynamic_states[0],
  }

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

  if vk.CreateGraphicsPipelines(device, 0, 1, &info, nil, &pipeline) != .SUCCESS do return pipeline, false

  return pipeline, true
}

create_render_pass :: proc(device: vk.Device, format: vk.Format) -> (vk.RenderPass, bool) {
  render_pass_attachments := [?]vk.AttachmentDescription {
    {
      format = format,
      samples = { ._1 },
      loadOp = .CLEAR,
      storeOp = .STORE,
      initialLayout = .UNDEFINED,
      finalLayout = .TRANSFER_SRC_OPTIMAL,
      stencilLoadOp = .DONT_CARE,
      stencilStoreOp = .DONT_CARE,
    }
  }

  subpass_color_attachments := [?]vk.AttachmentReference {
    {
      attachment = 0,
      layout = .COLOR_ATTACHMENT_OPTIMAL,
    }
  }

  render_pass_subpass := [?]vk.SubpassDescription {
    {
      pipelineBindPoint = .GRAPHICS,
      colorAttachmentCount = u32(len(subpass_color_attachments)),
      pColorAttachments = &subpass_color_attachments[0],
    }
  }

  render_pass_dependencies := [?]vk.SubpassDependency {
    {
      srcSubpass = vk.SUBPASS_EXTERNAL,
      dstSubpass = 0,
      srcAccessMask = { .MEMORY_READ },
      dstAccessMask = { .COLOR_ATTACHMENT_READ, .COLOR_ATTACHMENT_WRITE },
      srcStageMask = { .BOTTOM_OF_PIPE },
      dstStageMask = { .COLOR_ATTACHMENT_OUTPUT },
      dependencyFlags = { .BY_REGION },
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

get_drm_modifiers :: proc(physical_device: vk.PhysicalDevice, format: vk.Format, allocator: runtime.Allocator) -> []u64 {
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

  modifiers := make([]u64, count, allocator)
  drmFormatModifierProperties := make([]vk.DrmFormatModifierPropertiesEXT, count, allocator)
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

check_physical_device_ext_support :: proc(physical_device: vk.PhysicalDevice, allocator: runtime.Allocator) -> bool {
  count: u32
  available_extensions: []vk.ExtensionProperties
  err: mem.Allocator_Error

  vk.EnumerateDeviceExtensionProperties(physical_device, nil, &count, nil)
  if available_extensions, err = make([]vk.ExtensionProperties, count, allocator); err != nil do return false
  vk.EnumerateDeviceExtensionProperties(physical_device, nil, &count, &available_extensions[0])

  check :: proc(e: cstring, availables: []vk.ExtensionProperties) -> bool {
    for &available in availables do if e == cstring(&available.extensionName[0]) do return true

    return false
  }

  for ext in DEVICE_EXTENSIONS do if !check(ext, available_extensions) do return false
  
  return true
}

find_physical_device :: proc(instance: vk.Instance, allocator: runtime.Allocator) -> (vk.PhysicalDevice, bool) {
  physical_device: vk.PhysicalDevice

  devices: []vk.PhysicalDevice
  err: mem.Allocator_Error
  device_count: u32

  vk.EnumeratePhysicalDevices(instance, &device_count, nil)
  if devices, err = make([]vk.PhysicalDevice, device_count, allocator); err != nil do return physical_device, false
  vk.EnumeratePhysicalDevices(instance, &device_count, &devices[0])

  suitability :: proc(dev: vk.PhysicalDevice, allocator: runtime.Allocator) -> u32 {
    props: vk.PhysicalDeviceProperties
    features: vk.PhysicalDeviceFeatures

    vk.GetPhysicalDeviceProperties(dev, &props)
    vk.GetPhysicalDeviceFeatures(dev, &features)
    
    score: u32 = 10
    if props.deviceType == .DISCRETE_GPU do score += 1000

    if !check_physical_device_ext_support(dev, allocator) do return 0

    return score + props.limits.maxImageDimension2D
  }

  hiscore: u32 = 0
  for dev in devices {
    score := suitability(dev, allocator)
    if score > hiscore {
      physical_device = dev
      hiscore = score
    }
  }

  if hiscore == 0 do return physical_device, false

  return physical_device, true
}

create_queues :: proc(device: vk.Device, queue_indices: []u32, allocator: runtime.Allocator) -> ([]vk.Queue, bool) {
  queues: []vk.Queue
  err: mem.Allocator_Error
  if queues, err = make([]vk.Queue, len(queue_indices)); err != nil do return queues, false

  for &q, i in &queues {
    vk.GetDeviceQueue(device, u32(queue_indices[i]), 0, &q)
  }

  return queues, true
}

find_queue_indices :: proc(physical_device: vk.PhysicalDevice, allocator: runtime.Allocator) -> ([2]u32, bool) {
  MAX: u32 = 0xFF
  indices := [2]u32{ MAX, MAX}

  available_queues: []vk.QueueFamilyProperties
  err: mem.Allocator_Error

  queue_count: u32
  vk.GetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_count, nil)
  if available_queues, err = make([]vk.QueueFamilyProperties, queue_count, allocator); err != nil do return indices, false
  vk.GetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_count, raw_data(available_queues))

  for v, i in available_queues {
    if .GRAPHICS in v.queueFlags && indices[0] == MAX do indices[0] = u32(i)
    if .TRANSFER in v.queueFlags && indices[1] == MAX do indices[1] = u32(i)
  }

  for indice in indices {
    if indice == MAX do return indices, false
  }

  return indices, true
}

create_image :: proc(device: vk.Device, format: vk.Format, type: vk.ImageType, tiling: vk.ImageTiling, usage: vk.ImageUsageFlags, flags: vk.ImageCreateFlags, pNext: rawptr, modifiers: []u64, width: u32, height: u32) -> (image: vk.Image, ok: bool) {

  info := vk.ImageCreateInfo {
    sType = .IMAGE_CREATE_INFO,
    pNext = pNext,
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
    return image, false
  }

  return image, true
}

create_image_memory :: proc(device: vk.Device, physical_device: vk.PhysicalDevice, image: vk.Image, pNext: rawptr) -> (memory: vk.DeviceMemory, ok: bool) {
  requirements: vk.MemoryRequirements
  vk.GetImageMemoryRequirements(device, image, &requirements)

  alloc_info := vk.MemoryAllocateInfo{
    sType = .MEMORY_ALLOCATE_INFO,
    pNext = pNext,
    allocationSize = requirements.size,
    memoryTypeIndex = find_memory_type(physical_device, requirements.memoryTypeBits, { .HOST_VISIBLE, .HOST_COHERENT }) or_return
  }

  if vk.AllocateMemory(device, &alloc_info, nil, &memory) != .SUCCESS do return memory, false

  vk.BindImageMemory(device, image, memory, vk.DeviceSize(0))

  return memory, true
}

create_image_view :: proc(device: vk.Device, image: vk.Image, format: vk.Format) -> (vk.ImageView, bool) {
  components := vk.ComponentMapping {
    r = .R,
    g = .G,
    b = .B,
    a = .A,
  }

  range := vk.ImageSubresourceRange {
    levelCount = 1,
    layerCount = 1,
    aspectMask = { .COLOR },
    baseMipLevel = 0,
    baseArrayLayer = 0,
  }

  info := vk.ImageViewCreateInfo {
    sType = .IMAGE_VIEW_CREATE_INFO,
    image = image,
    viewType = .D2,
    format = format,
    components = components,
    subresourceRange = range,
  }

  view: vk.ImageView
  if vk.CreateImageView(device, &info, nil, &view) != .SUCCESS do return view, false

  return view, true
}

write_image :: proc(ctx: ^VulkanContext, width: u32, height: u32, buffer: []u8) -> bool {
  cmd := ctx.command_buffers[0]

  out_image := create_image(ctx.device, ctx.format, .D2, .LINEAR, { .TRANSFER_DST }, {}, nil, nil, width, height) or_return
  defer vk.DestroyImage(ctx.device, out_image, nil)

  out_memory := create_image_memory(ctx.device, ctx.physical_device, out_image, nil) or_return
  defer vk.FreeMemory(ctx.device, out_memory, nil)

  begin_info := vk.CommandBufferBeginInfo {
    sType = .COMMAND_BUFFER_BEGIN_INFO,
    flags = { .ONE_TIME_SUBMIT },
  }

  range := vk.ImageSubresourceRange {
    aspectMask = { .COLOR },
    baseMipLevel = 0,
    levelCount = 1,
    baseArrayLayer = 0,
    layerCount = 1,
  }

  image_barrier_1_info := vk.ImageMemoryBarrier {
    sType = .IMAGE_MEMORY_BARRIER,
    image = out_image,
    srcAccessMask = { },
    dstAccessMask = { .TRANSFER_WRITE },
    oldLayout = .UNDEFINED,
    newLayout = .TRANSFER_DST_OPTIMAL,
    subresourceRange = range,
  }

  image_barrier_2_info := vk.ImageMemoryBarrier {
    sType = .IMAGE_MEMORY_BARRIER,
    image = out_image,
    srcAccessMask = { .TRANSFER_WRITE },
    dstAccessMask = { .MEMORY_READ },
    oldLayout = .TRANSFER_DST_OPTIMAL,
    newLayout = .GENERAL,
    subresourceRange = range,
  }

  resource := vk.ImageSubresourceLayers {
    aspectMask = { .COLOR },
    baseArrayLayer = 0,
    layerCount = 1,
    mipLevel = 0,
  }

  srcOffset: vk.Offset3D
  dstOffset: vk.Offset3D
  extent := vk.Extent3D { width = ctx.width, height = ctx.height, depth = 1 }

  if ctx.width > width {
    srcOffset.x = i32(ctx.width - width)
    extent.width = width - u32(srcOffset.x)
  }

  if ctx.height > height {
    srcOffset.y = i32(ctx.height - height)
    extent.height = height - u32(srcOffset.y)
  }

  copy_info := vk.ImageCopy {
    srcSubresource = resource,
    dstSubresource = resource,
    srcOffset = srcOffset,
    dstOffset = dstOffset,
    extent = extent,
  }

  if vk.BeginCommandBuffer(cmd, &begin_info) != .SUCCESS do return false

  vk.CmdPipelineBarrier(cmd, { .TRANSFER }, { .TRANSFER }, {}, 0, nil, 0, nil, 1, &image_barrier_1_info)
  vk.CmdCopyImage(cmd, ctx.image, .TRANSFER_SRC_OPTIMAL, out_image, .TRANSFER_DST_OPTIMAL, 1, &copy_info)
  vk.CmdPipelineBarrier(cmd, { .TRANSFER }, { .TRANSFER }, {}, 0, nil, 0, nil, 1, &image_barrier_2_info)

  if vk.EndCommandBuffer(cmd) != .SUCCESS do return false

  submit_info := vk.SubmitInfo {
    sType = .SUBMIT_INFO,
    commandBufferCount = 1,
    pCommandBuffers = &cmd,
  }

  vk.ResetFences(ctx.device, 1, &ctx.fence)
  if vk.QueueSubmit(ctx.queues[1], 1, &submit_info, ctx.fence) != .SUCCESS do return false
  if vk.WaitForFences(ctx.device, 1, &ctx.fence, true, 0xFFFFFF) != .SUCCESS do return false

  image_resource := vk.ImageSubresource {
    aspectMask = { .COLOR },
  }

  layout: vk.SubresourceLayout
  vk.GetImageSubresourceLayout(ctx.device, out_image, &image_resource, &layout)

  out: [^]u8
  vk.MapMemory(ctx.device, out_memory, 0, vk.DeviceSize(vk.WHOLE_SIZE), {}, (^rawptr)(&out))
  defer vk.UnmapMemory(ctx.device, out_memory)

  for i in 0..<ctx.height {
    copy(buffer[i * width * 4:], out[i * u32(layout.rowPitch):][0:ctx.width * 4])
  }

  return true
}

create_framebuffer :: proc(device: vk.Device, render_pass: vk.RenderPass, view: ^vk.ImageView, width: u32, height: u32) -> (vk.Framebuffer, bool) {
  info := vk.FramebufferCreateInfo {
    sType = .FRAMEBUFFER_CREATE_INFO,
    renderPass = render_pass,
    attachmentCount = 1,
    pAttachments = view,
    width = width,
    height = height,
    layers = 1,
  }

  buffer: vk.Framebuffer
  if vk.CreateFramebuffer(device, &info, nil, &buffer) != .SUCCESS do return buffer, false

  return buffer, true
}

create_command_pool :: proc(device: vk.Device, queue_index: u32) -> (vk.CommandPool, bool) {
  pool_info: vk.CommandPoolCreateInfo
  pool_info.sType = .COMMAND_POOL_CREATE_INFO
  pool_info.flags = { .RESET_COMMAND_BUFFER }
  pool_info.queueFamilyIndex = queue_index

  command_pool: vk.CommandPool
  if res := vk.CreateCommandPool(device, &pool_info, nil, &command_pool); res != .SUCCESS do return command_pool, false

  return command_pool, true
}

allocate_command_buffers :: proc(device: vk.Device, command_pool: vk.CommandPool, count: u32, allocator: runtime.Allocator) -> ([]vk.CommandBuffer, bool) {
  alloc_info: vk.CommandBufferAllocateInfo
  alloc_info.sType = .COMMAND_BUFFER_ALLOCATE_INFO
  alloc_info.commandPool = command_pool
  alloc_info.level = .PRIMARY
  alloc_info.commandBufferCount = count

  command_buffers: []vk.CommandBuffer
  err: mem.Allocator_Error
  if command_buffers, err = make([]vk.CommandBuffer, count, allocator); err != nil do return command_buffers, false
  if res := vk.AllocateCommandBuffers(device, &alloc_info, &command_buffers[0]); res != .SUCCESS do return command_buffers, false

  return command_buffers, true
}

create_descriptor_pool :: proc(device: vk.Device) -> (vk.DescriptorPool, bool) {
  sizes := [?]vk.DescriptorPoolSize {
    {
      type = .UNIFORM_BUFFER,
      descriptorCount = 10, }
  }

  info := vk.DescriptorPoolCreateInfo {
    sType = .DESCRIPTOR_POOL_CREATE_INFO,
    poolSizeCount = u32(len(sizes)),
    pPoolSizes = &sizes[0],
    maxSets = 2,
  }

  pool: vk.DescriptorPool
  if vk.CreateDescriptorPool(device, &info, nil, &pool) != nil do return pool, false

  return pool, true
}

allocate_descriptor_sets :: proc(device: vk.Device, layouts: []vk.DescriptorSetLayout, pool: vk.DescriptorPool, buffer: vk.Buffer, binding: u32, allocator: runtime.Allocator) -> ([]vk.DescriptorSet, bool) {
  count := u32(len(layouts))
  info := vk.DescriptorSetAllocateInfo {
    sType = .DESCRIPTOR_SET_ALLOCATE_INFO,
    descriptorPool = pool,
    descriptorSetCount = count,
    pSetLayouts = &layouts[0],
  }

  sets: []vk.DescriptorSet
  err: mem.Allocator_Error

  if sets, err = make([]vk.DescriptorSet, count, allocator); err != nil do return sets, false
  if vk.AllocateDescriptorSets(device, &info, &sets[0]) != .SUCCESS do return sets, false

  buffer_info := vk.DescriptorBufferInfo {
    buffer = buffer,
    offset = 0,
    range = size_of(Vertex),
  }

  writes := [?]vk.WriteDescriptorSet {
    {
      sType = .WRITE_DESCRIPTOR_SET,
      dstSet = sets[0],
      dstBinding = binding,
      dstArrayElement = 0,
      descriptorCount = 1,
      descriptorType = .UNIFORM_BUFFER,
      pBufferInfo = &buffer_info,
    }
  }

  vk.UpdateDescriptorSets(device, u32(len(writes)), &writes[0], 0, nil)

  return sets, true
}

create_fence :: proc(device: vk.Device) -> (vk.Fence, bool) {
  info := vk.FenceCreateInfo {
    sType = .FENCE_CREATE_INFO,
    flags = { .SIGNALED },
  }

  fence: vk.Fence
  if vk.CreateFence(device, &info, nil, &fence) != .SUCCESS do return fence, false

  return fence, true
}

create_semaphore :: proc(device: vk.Device) -> (vk.Semaphore, bool) {
  info := vk.SemaphoreCreateInfo {
    sType = .SEMAPHORE_CREATE_INFO,
  }

  semaphore: vk.Semaphore
  if vk.CreateSemaphore(device, &info, nil, &semaphore) != .SUCCESS do return semaphore, false
  return semaphore, true
}

create_shader_module :: proc(device: vk.Device, path: string, allocator: runtime.Allocator) -> (vk.ShaderModule, bool) {
  module: vk.ShaderModule

  err: os.Error
  file: os.Handle
  size: i64

  if file, err = os.open(path); err != nil do return module, false
  defer os.close(file)

  if size, err = os.file_size(file); err != nil do return module, false

  buf: []u8
  if buf, err = make([]u8, size, allocator); err != nil do return module, false

  l: int
  if l, err = os.read(file, buf); err != nil do return module, false
  if int(size) != l do return module, false

  info := vk.ShaderModuleCreateInfo {
    sType = .SHADER_MODULE_CREATE_INFO,
    codeSize = int(size),
    pCode = cast([^]u32)(&buf[0])
  }

  frag_module: vk.ShaderModule
  if vk.CreateShaderModule(device, &info, nil, &module) != .SUCCESS do return module, false

  return module, true
}

find_memory_type :: proc(physical_device: vk.PhysicalDevice, type_filter: u32, properties: vk.MemoryPropertyFlags) -> (u32, bool) {
  mem_properties: vk.PhysicalDeviceMemoryProperties
  vk.GetPhysicalDeviceMemoryProperties(physical_device, &mem_properties)

  for i in 0..<mem_properties.memoryTypeCount {
    if (type_filter & (1 << i) != 0) && (mem_properties.memoryTypes[i].propertyFlags & properties) == properties do return i, true
  }

  return 0, false
}

create_buffer :: proc(device: vk.Device, size: vk.DeviceSize, usage: vk.BufferUsageFlags) -> (vk.Buffer, bool) {
  buf_info := vk.BufferCreateInfo {
    sType = .BUFFER_CREATE_INFO,
    pNext = nil,
    size = size,
    usage = usage,
    flags = {},
    sharingMode = .EXCLUSIVE,
  }

  buffer: vk.Buffer
  if vk.CreateBuffer(device, &buf_info, nil, &buffer) != .SUCCESS do return buffer, false

  return buffer, true
}

create_buffer_memory :: proc(device: vk.Device , physical_device: vk.PhysicalDevice, buffer: vk.Buffer, properties: vk.MemoryPropertyFlags) -> (memory: vk.DeviceMemory, ok: bool) {
  requirements: vk.MemoryRequirements
  vk.GetBufferMemoryRequirements(device, buffer, &requirements)

  alloc_info := vk.MemoryAllocateInfo{
    sType = .MEMORY_ALLOCATE_INFO,
    pNext = nil,
    allocationSize = requirements.size,
    memoryTypeIndex = find_memory_type(physical_device, requirements.memoryTypeBits, properties) or_return
  }

  if vk.AllocateMemory(device, &alloc_info, nil, &memory) != .SUCCESS do return memory, false

  vk.BindBufferMemory(device, buffer, memory, 0)

  return memory, true
}

copy_data :: proc($T: typeid, device: vk.Device, memory: vk.DeviceMemory, data: []T) {
  out: [^]T

  l := len(data)
  vk.MapMemory(device, memory, 0, vk.DeviceSize(l * size_of(T)), {}, (^rawptr)(&out))
  copy(out[0:l], data)
  vk.UnmapMemory(device, memory)
}

load_fn :: proc(ptr: rawptr, name: cstring) {
    (cast(^rawptr)ptr)^ = dynlib.symbol_address(library, string(name))
}

