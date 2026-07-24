pub const Pipeline = struct {
    handle: c.VkPipeline,
    layout: c.VkPipelineLayout,

    pub fn init(self: *Pipeline, context: *Context, input: Input, set_layouts: Descriptor.Set.Layouts) !void {
        const layouts = try set_layouts.build(context);

        const layout_info = c.VkPipelineLayoutCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
            .setLayoutCount = @intCast(layouts.handles.len),
            .pSetLayouts = layouts.handles.ptr,
        };

        if (c.VK_SUCCESS != context.lib.device.vkCreatePipelineLayout(context.device.handle, &layout_info, null, &self.layout)) return error.PipelineLayout;

        const input_description = try input.build(context.allocator.tmp);

        const vertex_input = c.VkPipelineVertexInputStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            .vertexBindingDescriptionCount = @intCast(input_description.bindings.len),
            .pVertexBindingDescriptions = input_description.bindings.ptr,
            .vertexAttributeDescriptionCount = @intCast(input_description.attributes.len),
            .pVertexAttributeDescriptions = input_description.attributes.ptr,
        };

        const input_assembly = c.VkPipelineInputAssemblyStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
            .topology = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
            .primitiveRestartEnable = c.VK_FALSE,
        };

        const viewport = c.VkPipelineViewportStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
            .viewportCount = 1,
            .scissorCount = 1,
        };

        const rasterization = c.VkPipelineRasterizationStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
            .depthClampEnable = c.VK_FALSE,
            .rasterizerDiscardEnable = c.VK_FALSE,
            .polygonMode = c.VK_POLYGON_MODE_FILL,
            .depthBiasEnable = c.VK_FALSE,
            .lineWidth = 1.0,
        };

        const blend_attachments = &[_]c.VkPipelineColorBlendAttachmentState{
            .{
                .colorWriteMask = c.VK_COLOR_COMPONENT_R_BIT | c.VK_COLOR_COMPONENT_G_BIT | c.VK_COLOR_COMPONENT_B_BIT | c.VK_COLOR_COMPONENT_A_BIT,
            },
        };

        const blend = c.VkPipelineColorBlendStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
            .attachmentCount = @intCast(blend_attachments.len),
            .pAttachments = blend_attachments.ptr,
        };

        const depth_stencil = c.VkPipelineDepthStencilStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
            .depthCompareOp = c.VK_COMPARE_OP_ALWAYS,
        };

        const multisample = c.VkPipelineMultisampleStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
            .rasterizationSamples = 1,
        };

        const dynamic_states = &[_]c.VkDynamicState{
            c.VK_DYNAMIC_STATE_VIEWPORT,
            c.VK_DYNAMIC_STATE_SCISSOR,
        };

        const dynamic_state = c.VkPipelineDynamicStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
            .dynamicStateCount = @intCast(dynamic_states.len),
            .pDynamicStates = dynamic_states.ptr,
        };

        const vertex_shader = try Module.init(context, "Asset/Shader/VertexShader.spv");
        defer vertex_shader.deinit(context);

        const fragment_shader = try Module.init(context, "Asset/Shader/FragmentShader.spv");
        defer fragment_shader.deinit(context);

        const shader = &[_]c.VkPipelineShaderStageCreateInfo{
            .{
                .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
                .module = vertex_shader.handle,
                .pName = "main",
            },
            .{
                .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
                .module = fragment_shader.handle,
                .pName = "main",
            },
        };

        const pipeline_rendering = c.VkPipelineRenderingCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO,
            .colorAttachmentCount = 1,
            .pColorAttachmentFormats = &context.swapchain.surface_format.format,
        };

        const info = c.VkGraphicsPipelineCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            .pNext = &pipeline_rendering,
            .stageCount = @intCast(shader.len),
            .pStages = shader.ptr,
            .pVertexInputState = &vertex_input,
            .pInputAssemblyState = &input_assembly,
            .pViewportState = &viewport,
            .pRasterizationState = &rasterization,
            .pMultisampleState = &multisample,
            .pDepthStencilState = &depth_stencil,
            .pColorBlendState = &blend,
            .pDynamicState = &dynamic_state,
            .layout = self.layout,
            .renderPass = null,
            .subpass = 0,
        };

        if (c.VK_SUCCESS != context.lib.device.vkCreateGraphicsPipelines(context.device.handle, null, 1, &info, null, &self.handle)) return error.PipelineCreate;
    }
};
const Device = @import("Device.zig").Device;
const Context = @import("Lib.zig").Context;
const Descriptor = @import("Shader.zig").Descriptor;
const Module = @import("Shader.zig").Module;
const Input = @import("Shader.zig").Input;
const std = @import("std");
const c = @import("Util").c;
