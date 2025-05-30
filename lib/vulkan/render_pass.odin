package vulk

import vk "vendor:vulkan"
import "core:log"

import "lib:collection/vector"
import "lib:error"

Render_Pass :: struct {
  handle: vk.RenderPass,
  pipelines: vector.Vector(Pipeline),
  layouts: vector.Vector(Pipeline_Layout),
  shaders: vector.Vector(Shader_Module),
  unused: vector.Vector(Pipeline),
}

update_shaders :: proc(ctx: ^Vulkan_Context) -> error.Error {
  log.info("Updating shaders")

  for i in 0..<ctx.render_pass.shaders.len {
    shader_module_update(&ctx.render_pass.shaders.data[i], ctx) or_return
  }

  for i in 0..<ctx.render_pass.pipelines.len {
    vector.append(&ctx.render_pass.unused, ctx.render_pass.pipelines.data[i]) or_return
    pipeline_update(&ctx.render_pass.pipelines.data[i], ctx, &ctx.render_pass) or_return
  }

  for i in 0..<ctx.render_pass.shaders.len {
    shader_module_destroy(ctx, &ctx.render_pass.shaders.data[i])
  }

  return nil
}

@private
render_pass_create :: proc(ctx: ^Vulkan_Context) -> (render_pass: Render_Pass, err: error.Error) {
  render_pass_attachments := [?]vk.AttachmentDescription {
    {
      format = ctx.format,
      samples = {._1},
      loadOp = .CLEAR,
      storeOp = .STORE,
      initialLayout = .UNDEFINED,
      finalLayout = .COLOR_ATTACHMENT_OPTIMAL,
      stencilLoadOp = .DONT_CARE,
      stencilStoreOp = .DONT_CARE,
    },
    {
      format = ctx.depth_format,
      samples = {._1},
      loadOp = .CLEAR,
      storeOp = .STORE,
      initialLayout = .UNDEFINED,
      finalLayout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
      stencilLoadOp = .DONT_CARE,
      stencilStoreOp = .DONT_CARE,
    },
  }

  subpass_color_attachments := [?]vk.AttachmentReference {
    {attachment = 0, layout = .COLOR_ATTACHMENT_OPTIMAL},
  }

  subpass_depth_attachments := [?]vk.AttachmentReference {
    {attachment = 1, layout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL},
  }

  render_pass_subpass := [?]vk.SubpassDescription {
    {
      pipelineBindPoint = .GRAPHICS,
      colorAttachmentCount = u32(len(subpass_color_attachments)),
      pColorAttachments = &subpass_color_attachments[0],
      pDepthStencilAttachment = &subpass_depth_attachments[0],
    },
  }

  render_pass_dependencies := [?]vk.SubpassDependency {
    {
      srcSubpass = vk.SUBPASS_EXTERNAL,
      dstSubpass = 0,
      srcStageMask = {.COLOR_ATTACHMENT_OUTPUT, .EARLY_FRAGMENT_TESTS},
      srcAccessMask = {},
      dstStageMask = {.COLOR_ATTACHMENT_OUTPUT, .EARLY_FRAGMENT_TESTS},
      dstAccessMask = {.COLOR_ATTACHMENT_WRITE, .DEPTH_STENCIL_ATTACHMENT_WRITE},
      dependencyFlags = {.BY_REGION},
    },
  }

  render_pass_info := vk.RenderPassCreateInfo {
    sType     = .RENDER_PASS_CREATE_INFO,
    attachmentCount = u32(len(render_pass_attachments)),
    pAttachments    = &render_pass_attachments[0],
    subpassCount    = u32(len(render_pass_subpass)),
    pSubpasses      = &render_pass_subpass[0],
    dependencyCount = u32(len(render_pass_dependencies)),
    pDependencies   = &render_pass_dependencies[0],
  }

  if vk.CreateRenderPass(ctx.device.handle, &render_pass_info, nil, &render_pass.handle) != .SUCCESS do return render_pass, .CreateRenderPassFailed

  render_pass.layouts = vector.new(Pipeline_Layout, 10, ctx.allocator) or_return
  render_pass.pipelines = vector.new(Pipeline, 10, ctx.allocator) or_return
  render_pass.unused = vector.new(Pipeline, 10, ctx.allocator) or_return
  render_pass.shaders = vector.new(Shader_Module, 10, ctx.allocator) or_return

  return render_pass, nil
}

@private
render_pass_append_layout :: proc(render_pass: ^Render_Pass, p_layout: Pipeline_Layout) -> (layout: ^Pipeline_Layout, err: error.Error) {
  layout = vector.one(&render_pass.layouts) or_return
  layout^ = p_layout

  return layout, nil
}

@private
render_pass_append_shader :: proc(ctx: ^Vulkan_Context, render_pass: ^Render_Pass, path: string) -> (module: ^Shader_Module, err: error.Error) {
  module = vector.one(&render_pass.shaders) or_return
  shader_module_create(module, ctx, path) or_return

  return module, nil
}

@private
render_pass_append_pipeline :: proc(ctx: ^Vulkan_Context, render_pass: ^Render_Pass, layout: ^Pipeline_Layout, vertex_shader: ^Shader_Module, fragment_shader: ^Shader_Module, vertex_attribute_bindings: [][]Vertex_Attribute) -> (pipeline: ^Pipeline, err: error.Error) {
  pipeline = vector.one(&render_pass.pipelines) or_return
  pipeline_create(pipeline, ctx, render_pass, layout, vertex_shader, fragment_shader, vertex_attribute_bindings) or_return

  return pipeline, nil
}

render_pass_destroy_unused :: proc(ctx: ^Vulkan_Context, render_pass: ^Render_Pass) {
  for i in 0..<render_pass.unused.len {
    vk.DestroyPipeline(ctx.device.handle, render_pass.unused.data[i].handle, nil)
  }

  render_pass.unused.len = 0
}

@private
render_pass_deinit :: proc(ctx: ^Vulkan_Context, render_pass: ^Render_Pass) {

  for i in 0..<render_pass.pipelines.len {
    vk.DestroyPipeline(ctx.device.handle, render_pass.pipelines.data[i].handle, nil)
  }

  for i in 0..<render_pass.layouts.len {
    vk.DestroyPipelineLayout(ctx.device.handle, render_pass.layouts.data[i].handle, nil)
  }

  vk.DestroyRenderPass(ctx.device.handle, render_pass.handle, nil)
}
