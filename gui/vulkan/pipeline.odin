package vulk

import "base:runtime"
import "core:os"
import vk "vendor:vulkan"
import "./../collection"

import "./../error"

@private
Pipeline_Layout :: struct {
  handle: vk.PipelineLayout,
  sets: collection.Vector(^Descriptor_Set_Layout),
}

// @private
// Pipeline_Info :: struct {
//   layout: ^Pipeline_Layout,
//   geometries: Geometry_Group,
//   vert: string,
//   frag: string,
// }

@private
Pipeline :: struct {
  handle: vk.Pipeline,
  layout: ^Pipeline_Layout,
  geometries: ^Geometry_Group,
}

Vertex_Attribute_Kind :: enum{
  Sfloat,
  Uint,
}

Vertex_Attribute :: struct {
  kind: Vertex_Attribute_Kind,
  count: u32,
}

@private
get_attribute_format :: proc(attribute: Vertex_Attribute) -> (format: vk.Format, size: u32, err: error.Error) {
  switch attribute.kind {
    case .Sfloat:
      size = size_of(f32)
    case .Uint:
      size  = size_of(u32)
  }

  switch attribute.count {
    case 2:
      switch attribute.kind {
        case .Sfloat:
          format = .R32G32_SFLOAT
        case .Uint:
          format = .R32G32_UINT
      }
    case 3:
      switch attribute.kind {
        case .Sfloat:
          format = .R32G32B32_SFLOAT
        case .Uint:
          format = .R32G32B32_UINT
      }
    case 4:
      switch attribute.kind {
        case .Sfloat:
          format = .R32G32B32A32_SFLOAT
        case .Uint:
          format = .R32G32B32A32_UINT
      }
    case:
      return format, size, .InvalidFormat
  }

  size = size * attribute.count

  return format, size, nil
}

@private
pipeline_create :: proc(ctx: ^Vulkan_Context, render_pass: ^Render_Pass, layout: ^Pipeline_Layout, geometries: ^Geometry_Group, vert: string, frag: string, vertex_attribute_bindings: [][]Vertex_Attribute) -> (pipeline: Pipeline, err: error.Error) {
  pipeline.layout = layout
  pipeline.geometries = geometries

  vert_module := shader_module_create(ctx, vert) or_return
  defer vk.DestroyShaderModule(ctx.device.handle, vert_module, nil)

  frag_module := shader_module_create(ctx, frag) or_return
  defer vk.DestroyShaderModule(ctx.device.handle, frag_module, nil)

  stages := [?]vk.PipelineShaderStageCreateInfo {
    {
      sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
      stage = {.VERTEX},
      module = vert_module,
      pName = cstring("main"),
    },
    {
      sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
      stage = {.FRAGMENT},
      module = frag_module,
      pName = cstring("main"),
    },
  }

  vertex_binding_descriptions := collection.new_vec(vk.VertexInputBindingDescription, u32(len(vertex_attribute_bindings)), ctx.tmp_allocator) or_return
  vertex_attribute_descriptions := collection.new_vec(vk.VertexInputAttributeDescription, 100, ctx.tmp_allocator) or_return

  for i in 0..<len(vertex_attribute_bindings) {
    offset: u32 = 0
    for j in 0..<len(vertex_attribute_bindings[i]) {
      format, size := get_attribute_format(vertex_attribute_bindings[i][j]) or_return
      description := collection.vec_one(&vertex_attribute_descriptions) or_return
      description.binding = u32(i)
      description.location = u32(j)
      description.offset = offset
      description.format = format
      offset += size
    }

    binding := collection.vec_one(&vertex_binding_descriptions) or_return
    binding.binding = u32(i)
    binding.stride = offset
    binding.inputRate = .VERTEX
  }

  vert_input_state := vk.PipelineVertexInputStateCreateInfo {
    sType         = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
    vertexBindingDescriptionCount   = vertex_binding_descriptions.len,
    pVertexBindingDescriptions      = &vertex_binding_descriptions.data[0],
    vertexAttributeDescriptionCount = vertex_attribute_descriptions.len,
    pVertexAttributeDescriptions    = &vertex_attribute_descriptions.data[0],
  }

  viewports := [?]vk.Viewport {
    {x = 0, y = 0, width = 0, height = 0, minDepth = 0, maxDepth = 1},
  }

  scissors := [?]vk.Rect2D {
    {
      offset = vk.Offset2D{x = 0, y = 0},
      extent = vk.Extent2D{width = 0, height = 0},
    },
  }

  viewport_state := vk.PipelineViewportStateCreateInfo {
    sType   = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
    viewportCount = u32(len(viewports)),
    pViewports    = &viewports[0],
    scissorCount  = u32(len(scissors)),
    pScissors     = &scissors[0],
  }

  multisample_state := vk.PipelineMultisampleStateCreateInfo {
    sType     = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
    rasterizationSamples  = {._1},
    sampleShadingEnable   = false,
    alphaToOneEnable      = false,
    alphaToCoverageEnable = false,
    minSampleShading      = 1.0,
  }

  depth_stencil_stage := vk.PipelineDepthStencilStateCreateInfo {
    sType     = .PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
    depthTestEnable       = true,
    depthWriteEnable      = true,
    depthCompareOp  = .LESS,
    depthBoundsTestEnable = false,
    stencilTestEnable     = false,
    minDepthBounds  = 0.0,
    maxDepthBounds  = 1.0,
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
      colorWriteMask = {.R, .G, .B, .A},
    },
  }

  color_blend_state := vk.PipelineColorBlendStateCreateInfo {
    sType     = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
    logicOpEnable   = false,
    attachmentCount = u32(len(color_blend_attachments)),
    pAttachments    = &color_blend_attachments[0],
    blendConstants  = {0, 0, 0, 0},
  }

  rasterization_state := vk.PipelineRasterizationStateCreateInfo {
    sType       = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
    depthClampEnable  = false,
    rasterizerDiscardEnable = false,
    polygonMode       = .FILL,
    cullMode    = {.FRONT},
    frontFace         = .CLOCKWISE,
    depthBiasEnable   = false,
    depthBiasClamp    = 0.0,
    depthBiasConstantFactor = 0.0,
    depthBiasSlopeFactor    = 0.0,
    lineWidth         = 1,
  }

  input_assembly_state := vk.PipelineInputAssemblyStateCreateInfo {
    sType    = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
    topology = .TRIANGLE_LIST,
  }

  dynamic_states := [?]vk.DynamicState{.VIEWPORT, .SCISSOR}

  dynamic_state := vk.PipelineDynamicStateCreateInfo {
    sType       = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
    dynamicStateCount = u32(len(dynamic_states)),
    pDynamicStates    = &dynamic_states[0],
  }

  info := vk.GraphicsPipelineCreateInfo {
    sType         = .GRAPHICS_PIPELINE_CREATE_INFO,
    stageCount    = u32(len(stages)),
    pStages       = &stages[0],
    pViewportState      = &viewport_state,
    pVertexInputState   = &vert_input_state,
    pMultisampleState   = &multisample_state,
    pDepthStencilState  = &depth_stencil_stage,
    pColorBlendState    = &color_blend_state,
    pRasterizationState = &rasterization_state,
    pInputAssemblyState = &input_assembly_state,
    pDynamicState       = &dynamic_state,
    renderPass    = render_pass.handle,
    layout        = pipeline.layout.handle,
  }

  if vk.CreateGraphicsPipelines(ctx.device.handle, 0, 1, &info, nil, &pipeline.handle) != .SUCCESS do return pipeline, .CreatePipelineFailed

  return pipeline, nil
}

@private
layout_create :: proc(ctx: ^Vulkan_Context, set_layouts: []^Descriptor_Set_Layout) -> (layout: Pipeline_Layout, err: error.Error) {
  layouts := make([]vk.DescriptorSetLayout, len(set_layouts), ctx.tmp_allocator)
  layout.sets = collection.new_vec(^Descriptor_Set_Layout, u32(len(set_layouts)), ctx.allocator) or_return

  for i in 0..<len(set_layouts) {
    collection.vec_append(&layout.sets, set_layouts[i]) or_return
    layouts[i] = set_layouts[i].handle
  }

  layout_info := vk.PipelineLayoutCreateInfo {
    sType    = .PIPELINE_LAYOUT_CREATE_INFO,
    setLayoutCount = u32(len(layouts)),
    pSetLayouts    = &layouts[0],
  }

  if vk.CreatePipelineLayout(ctx.device.handle, &layout_info, nil, &layout.handle) != .SUCCESS {
    return layout, .CreatePipelineLayouFailed
  }

  return layout, nil
}

@private
shader_module_create :: proc(ctx: ^Vulkan_Context, path: string) -> (module: vk.ShaderModule, err: error.Error) {
  er: os.Error
  file: os.Handle
  size: i64

  if file, er = os.open(path); er != nil do return module, .FileNotFound
  defer os.close(file)

  if size, er = os.file_size(file); er != nil do return module, .FileNotFound

  buf := make([]u8, u32(size), ctx.tmp_allocator)

  l: int
  if l, er = os.read(file, buf); er != nil do return module, .ReadFileFailed
  if int(size) != l do return module, .SizeNotMatch

  info := vk.ShaderModuleCreateInfo {
    sType    = .SHADER_MODULE_CREATE_INFO,
    codeSize = int(size),
    pCode    = cast([^]u32)(&buf[0]),
  }

  frag_module: vk.ShaderModule
  if vk.CreateShaderModule(ctx.device.handle, &info, nil, &module) != .SUCCESS do return module, .CreateShaderModuleFailed

  return module, nil
}

pipeline_deinit :: proc(ctx: ^Vulkan_Context, pipeline: Pipeline) {
  for i in 0 ..< pipeline.geometries.childs.len {
  	destroy_geometry(ctx, &pipeline.geometries.childs.data[i])
  }

  vk.DestroyPipeline(ctx.device.handle, pipeline.handle, nil)
}
