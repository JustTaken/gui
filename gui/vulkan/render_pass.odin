package vulk

import vk "vendor:vulkan"
import "./../collection"

import "./../error"

Render_Pass :: struct {
	handle: vk.RenderPass,
	pipelines: collection.Vector(Pipeline),
	layouts: collection.Vector(Pipeline_Layout),
}


@private
render_pass_create :: proc(ctx: ^Vulkan_Context, layouts: []Pipeline_Layout) -> (render_pass: Render_Pass, err: error.Error) {
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

  render_pass.layouts = collection.new_vec(Pipeline_Layout, u32(len(layouts)), ctx.allocator) or_return
  render_pass.pipelines = collection.new_vec(Pipeline, 1, ctx.allocator) or_return

  for i in 0..<len(layouts) {
  	collection.vec_append(&render_pass.layouts, layouts[i]) or_return
  	collection.vec_append(&render_pass.pipelines, pipeline_create(ctx, render_pass.handle, &render_pass.layouts.data[i], {{.STORAGE_BUFFER, 20, {.STORAGE_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}}, {.STORAGE_BUFFER, 20, {.STORAGE_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}}, {.STORAGE_BUFFER, 20, {.STORAGE_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}}}) or_return) or_return
  }
  // for i in 0..<count {
  // group.set = descriptor_set_allocate(ctx, &ctx.descriptor_pool, ctx.render_pass.layouts.data[0].sets.data[1], {{.STORAGE_BUFFER, 20, {.STORAGE_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}}, {.STORAGE_BUFFER, 20, {.STORAGE_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}}, {.STORAGE_BUFFER, 20, {.STORAGE_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}}}) or_return
  	// collection.vec_append(&render_pass.pipelines, pipeline_create(ctx, render_pass.handle, &render_pass.layouts.data[0], {{.STORAGE_BUFFER, 20, {.STORAGE_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}}, {.STORAGE_BUFFER, 20, {.STORAGE_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}}, {.STORAGE_BUFFER, 20, {.STORAGE_BUFFER, .TRANSFER_DST}, {.DEVICE_LOCAL}}}) or_return) or_return
  // }

  return render_pass, nil
}

render_pass_deinit :: proc(ctx: ^Vulkan_Context, render_pass: ^Render_Pass) {
	for i in 0..<render_pass.pipelines.len {
		pipeline_deinit(ctx, render_pass.pipelines.data[i])
	}

	vk.DestroyRenderPass(ctx.device.handle, render_pass.handle, nil)
}
