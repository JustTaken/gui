const MAX_FRAMES: u32 = 10;

const LibraryPointers = struct {
    vkEnumerateInstanceLayerProperties: @typeInfo(c.PFN_vkEnumerateInstanceLayerProperties).optional.child,
    vkCreateInstance: @typeInfo(c.PFN_vkCreateInstance).optional.child,
    vkGetInstanceProcAddr: @typeInfo(c.PFN_vkGetInstanceProcAddr).optional.child,
};

const InstancePointers = struct {
    vkEnumeratePhysicalDevices: @typeInfo(c.PFN_vkEnumeratePhysicalDevices).optional.child,
    vkGetPhysicalDeviceProperties: @typeInfo(c.PFN_vkGetPhysicalDeviceProperties).optional.child,
    vkGetPhysicalDeviceQueueFamilyProperties: @typeInfo(c.PFN_vkGetPhysicalDeviceQueueFamilyProperties).optional.child,
    vkGetPhysicalDeviceSurfaceSupportKHR: @typeInfo(c.PFN_vkGetPhysicalDeviceSurfaceSupportKHR).optional.child,
    vkCreateWaylandSurfaceKHR: @typeInfo(c.PFN_vkCreateWaylandSurfaceKHR).optional.child,
    vkGetPhysicalDeviceFeatures2: @typeInfo(c.PFN_vkGetPhysicalDeviceFeatures2).optional.child,
    vkEnumerateDeviceExtensionProperties: @typeInfo(c.PFN_vkEnumerateDeviceExtensionProperties).optional.child,
    vkGetPhysicalDeviceMemoryProperties: @typeInfo(c.PFN_vkGetPhysicalDeviceMemoryProperties).optional.child,
    vkCreateDevice: @typeInfo(c.PFN_vkCreateDevice).optional.child,
    vkGetPhysicalDeviceSurfaceCapabilitiesKHR: @typeInfo(c.PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR).optional.child,
    vkGetPhysicalDeviceSurfaceFormatsKHR: @typeInfo(c.PFN_vkGetPhysicalDeviceSurfaceFormatsKHR).optional.child,
    vkGetDeviceProcAddr: @typeInfo(c.PFN_vkGetDeviceProcAddr).optional.child,
};

const DevicePointers = struct {
    vkGetDeviceQueue: @typeInfo(c.PFN_vkGetDeviceQueue).optional.child,
    vkDestroyCommandPool: @typeInfo(c.PFN_vkDestroyCommandPool).optional.child,
    vkCreateBuffer: @typeInfo(c.PFN_vkCreateBuffer).optional.child,
    vkGetBufferMemoryRequirements: @typeInfo(c.PFN_vkGetBufferMemoryRequirements).optional.child,
    vkAllocateMemory: @typeInfo(c.PFN_vkAllocateMemory).optional.child,
    vkBindBufferMemory: @typeInfo(c.PFN_vkBindBufferMemory).optional.child,
    vkMapMemory: @typeInfo(c.PFN_vkMapMemory).optional.child,
    vkUnmapMemory: @typeInfo(c.PFN_vkUnmapMemory).optional.child,
    vkCreateSwapchainKHR: @typeInfo(c.PFN_vkCreateSwapchainKHR).optional.child,
    vkDestroySwapchainKHR: @typeInfo(c.PFN_vkDestroySwapchainKHR).optional.child,
    vkGetSwapchainImagesKHR: @typeInfo(c.PFN_vkGetSwapchainImagesKHR).optional.child,
    vkCreateImageView: @typeInfo(c.PFN_vkCreateImageView).optional.child,
    vkDestroyImageView: @typeInfo(c.PFN_vkDestroyImageView).optional.child,
    vkCreatePipelineLayout: @typeInfo(c.PFN_vkCreatePipelineLayout).optional.child,
    vkCreateShaderModule: @typeInfo(c.PFN_vkCreateShaderModule).optional.child,
    vkDestroyShaderModule: @typeInfo(c.PFN_vkDestroyShaderModule).optional.child,
    vkCreateGraphicsPipelines: @typeInfo(c.PFN_vkCreateGraphicsPipelines).optional.child,
    vkCreateCommandPool: @typeInfo(c.PFN_vkCreateCommandPool).optional.child,
    vkAllocateCommandBuffers: @typeInfo(c.PFN_vkAllocateCommandBuffers).optional.child,
    vkCreateFence: @typeInfo(c.PFN_vkCreateFence).optional.child,
    vkCreateSemaphore: @typeInfo(c.PFN_vkCreateSemaphore).optional.child,
    vkAcquireNextImageKHR: @typeInfo(c.PFN_vkAcquireNextImageKHR).optional.child,
    vkWaitForFences: @typeInfo(c.PFN_vkWaitForFences).optional.child,
    vkResetFences: @typeInfo(c.PFN_vkResetFences).optional.child,
    vkBeginCommandBuffer: @typeInfo(c.PFN_vkBeginCommandBuffer).optional.child,
    vkCmdBeginRendering: @typeInfo(c.PFN_vkCmdBeginRendering).optional.child,
    vkCmdBindPipeline: @typeInfo(c.PFN_vkCmdBindPipeline).optional.child,
    vkCmdSetViewport: @typeInfo(c.PFN_vkCmdSetViewport).optional.child,
    vkCmdSetScissor: @typeInfo(c.PFN_vkCmdSetScissor).optional.child,
    vkCmdBindVertexBuffers: @typeInfo(c.PFN_vkCmdBindVertexBuffers).optional.child,
    vkCmdDraw: @typeInfo(c.PFN_vkCmdDraw).optional.child,
    vkCmdEndRendering: @typeInfo(c.PFN_vkCmdEndRendering).optional.child,
    vkEndCommandBuffer: @typeInfo(c.PFN_vkEndCommandBuffer).optional.child,
    vkQueueSubmit: @typeInfo(c.PFN_vkQueueSubmit).optional.child,
    vkQueuePresentKHR: @typeInfo(c.PFN_vkQueuePresentKHR).optional.child,
    vkCmdPipelineBarrier2: @typeInfo(c.PFN_vkCmdPipelineBarrier2).optional.child,
    vkQueueWaitIdle: @typeInfo(c.PFN_vkQueueWaitIdle).optional.child,
    vkCmdDrawIndexed: @typeInfo(c.PFN_vkCmdDrawIndexed).optional.child,
    vkCmdBindIndexBuffer: @typeInfo(c.PFN_vkCmdBindIndexBuffer).optional.child,
    vkCreateDescriptorSetLayout: @typeInfo(c.PFN_vkCreateDescriptorSetLayout).optional.child,
    vkCreateDescriptorPool: @typeInfo(c.PFN_vkCreateDescriptorPool).optional.child,
    vkUpdateDescriptorSets: @typeInfo(c.PFN_vkUpdateDescriptorSets).optional.child,
    vkAllocateDescriptorSets: @typeInfo(c.PFN_vkAllocateDescriptorSets).optional.child,
    vkCmdBindDescriptorSets: @typeInfo(c.PFN_vkCmdBindDescriptorSets).optional.child,
    vkWaitSemaphores: @typeInfo(c.PFN_vkWaitSemaphores).optional.child,
};

pub const Library = struct {
    handle: std.DynLib,
    pfn: LibraryPointers = undefined,
    instance: InstancePointers = undefined,
    device: DevicePointers = undefined,

    pub fn init(self: *Library) !void {
        self.handle = std.DynLib.open("libvulkan.so") catch return error.VulkanLibrary;

        inline for (@typeInfo(LibraryPointers).@"struct".fields) |field| {
            if (self.handle.lookup(field.type, field.name)) |ptr| {
                @field(&self.pfn, field.name) = @ptrCast(ptr);
            } else {
                std.debug.print("Missing  symbol: {s}\n", .{field.name});
                return error.LibrarySymbol;
            }
        }
    }

    pub fn load_instance(self: *Library, instance: c.VkInstance) !void {
        inline for (@typeInfo(InstancePointers).@"struct".fields) |field| {
            if (self.pfn.vkGetInstanceProcAddr(instance, field.name)) |ptr| {
                @field(&self.instance, field.name) = @ptrCast(ptr);
            } else {
                std.debug.print("Missing  symbol: {s}\n", .{field.name});
                return error.LibrarySymbol;
            }
        }
    }

    pub fn load_device(self: *Library, device: c.VkDevice) !void {
        inline for (@typeInfo(DevicePointers).@"struct".fields) |field| {
            if (self.instance.vkGetDeviceProcAddr(device, field.name)) |ptr| {
                @field(&self.device, field.name) = @ptrCast(ptr);
            } else {
                std.debug.print("Missing  symbol: {s}\n", .{field.name});
                return error.LibrarySymbol;
            }
        }
    }
};

pub const Context = struct {
    lib: Library,
    instance: Instance,
    surface: Surface,
    device: Device,

    swapchain: Swapchain,
    pipeline: Pipeline,
    command_allocator: Command.Allocator,
    descriptor_allocator: Descriptor.Allocator,

    set_layouts: Descriptor.Set.Layouts,

    semaphores: Semaphores,
    fences: Fences,

    render_groups: std.ArrayList(RenderGroup),
    sets_to_update: std.ArrayList(Descriptor.UpdateInfo),

    allocator: *Allocator,

    pub const Vertex = struct {
        position: [3]f32,
        color: [3]f32,
    };

    pub fn init(
        self: *Context,
        display: ?*c.wl_display,
        surface: ?*c.wl_surface,
        width: u32,
        height: u32,
        allocator: *Allocator,
    ) !void {
        self.allocator = allocator;

        try self.lib.init();

        try self.instance.init(self);
        try self.surface.init(self, display, surface);
        try self.device.init(self);

        self.semaphores.init();
        self.fences.init();

        try self.command_allocator.init(self, 10);
        try self.swapchain.startup(self, width, height);

        const input_layouts = [_]Input.Layout{
            try .init(Vertex, self),
        };

        const input = try Input.init(&input_layouts, self.allocator.tmp);

        const set_layouts = [_]Descriptor.Set.Layout{
            try .init(self, &.{Descriptor.Set.Layout.Binding.init(.storage, .vertex, 1)}),
            try .init(self, &.{Descriptor.Set.Layout.Binding.init(.uniform, .vertex, 1)}),
        };

        self.set_layouts = try Descriptor.Set.Layouts.init(self, &set_layouts);

        try self.pipeline.init(self, input, self.set_layouts);

        const descriptor_sizes = [_]Descriptor.Size{
            .init(.storage, 10),
            .init(.uniform, 10),
        };

        try self.descriptor_allocator.init(self, &descriptor_sizes, 20);

        self.sets_to_update = try std.ArrayList(Descriptor.UpdateInfo).initCapacity(self.allocator.main, 10);
        self.render_groups = try std.ArrayList(RenderGroup).initCapacity(self.allocator.main, 10);
    }

    pub fn addDescriptorSet(self: *Context, index: usize) !*Descriptor.Set {
        const descriptor = try self.descriptor_allocator.alloc(self, self.set_layouts.childs[index..]);

        return &descriptor[0];
    }

    pub fn updateDescriptorSet(self: *Context, set: *Descriptor.Set, range: Buffer.Range, binding: u32) void {
        self.sets_to_update.appendAssumeCapacity(.{
            .set = set,
            .binding = binding,
            .range = range,
        });
    }

    pub fn addPublicBuffer(self: *Context, T: type, kind: Buffer.Usage.Kind, capacity: usize) !Buffer {
        return try Buffer.init(
            T,
            self,
            .init(&.{kind}),
            .init(&.{ .host_visible, .host_coherent }),
            .exclusive,
            capacity,
        );
    }

    pub fn addRenderGroup(self: *Context, vertices: []Vertex, indices: []u16, sets: []const *Descriptor.Set) !*RenderGroup {
        var vert = try Buffer.init(Vertex, self, .init(&.{.vertex}), .init(&.{ .host_visible, .host_coherent }), .exclusive, vertices.len);
        var ind = try Buffer.init(u16, self, .init(&.{.index}), .init(&.{ .host_visible, .host_coherent }), .exclusive, indices.len);

        try vert.append(Vertex, self, vertices);
        try ind.append(u16, self, indices);

        const render = try self.render_groups.addOne(self.allocator.main);
        try render.init(self, vert, ind, sets);

        return render;
    }

    pub fn changeRenderSize(self: *Context, width: u32, height: u32) !void {
        try self.swapchain.new(self, width, height);
    }

    pub fn renderFrame(self: *Context) !void {
        const image = try self.swapchain.nextImage(self);
        const command_buffer = &self.swapchain.command_buffers[image];
        const swapchain_semaphore = self.swapchain.semaphores[image];
        const extent = self.swapchain.extent;

        for (self.sets_to_update.items) |update| {
            try update.set.update(self, update.range, update.binding);
        }

        self.sets_to_update.clearRetainingCapacity();

        const begin_info = c.VkCommandBufferBeginInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        };

        const background_color = .{ 0.0, 0.0, 0.0, 1.0 };

        const clear_color = c.VkClearValue{
            .color = .{ .float32 = background_color },
        };

        const color_attachment = c.VkRenderingAttachmentInfo{
            .sType = c.VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO,
            .imageView = self.swapchain.image_views[image],
            .imageLayout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
            .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
            .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
            .clearValue = clear_color,
        };

        const rendering_info = c.VkRenderingInfo{
            .sType = c.VK_STRUCTURE_TYPE_RENDERING_INFO_KHR,
            .layerCount = 1,
            .colorAttachmentCount = 1,
            .pColorAttachments = &color_attachment,
            .renderArea = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = extent,
            },
        };

        const viewport = c.VkViewport{
            .width = @floatFromInt(extent.width),
            .height = @floatFromInt(extent.height),
            .minDepth = 0.0,
            .maxDepth = 1.0,
        };

        const scissor = c.VkRect2D{
            .extent = extent,
        };

        const offset = [_]c.VkDeviceSize{0};

        if (c.VK_SUCCESS != self.lib.device.vkBeginCommandBuffer(command_buffer.handle, &begin_info)) return error.BeginCommandBuffer;

        transitionImage(
            self,
            command_buffer,
            self.swapchain.images[image],
            c.VK_IMAGE_LAYOUT_UNDEFINED,
            c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
            c.VK_PIPELINE_STAGE_2_TOP_OF_PIPE_BIT,
            c.VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT,
            0,
            c.VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT,
        );

        self.lib.device.vkCmdBeginRendering(command_buffer.handle, &rendering_info);
        self.lib.device.vkCmdBindPipeline(command_buffer.handle, c.VK_PIPELINE_BIND_POINT_GRAPHICS, self.pipeline.handle);
        self.lib.device.vkCmdSetViewport(command_buffer.handle, 0, 1, &viewport);
        self.lib.device.vkCmdSetScissor(command_buffer.handle, 0, 1, &scissor);

        for (0..self.render_groups.items.len) |i| {
            const r = self.render_groups.items[i];

            const sets = try self.allocator.tmp.alloc(c.VkDescriptorSet, r.sets.len);

            for (0..sets.len) |j| {
                sets[j] = r.sets[j].handle;
            }

            self.lib.device.vkCmdBindVertexBuffers(command_buffer.handle, 0, 1, &r.vertices.handle, &offset);
            self.lib.device.vkCmdBindIndexBuffer(command_buffer.handle, r.indices.handle, 0, c.VK_INDEX_TYPE_UINT16);
            self.lib.device.vkCmdBindDescriptorSets(command_buffer.handle, c.VK_PIPELINE_BIND_POINT_GRAPHICS, self.pipeline.layout, 0, @intCast(sets.len), sets.ptr, 0, null);
            self.lib.device.vkCmdDrawIndexed(command_buffer.handle, r.indices.len, @intCast(sets.len), 0, 0, 0);
        }

        self.lib.device.vkCmdEndRendering(command_buffer.handle);

        transitionImage(
            self,
            command_buffer,
            self.swapchain.images[image],
            c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
            c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
            c.VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT,
            c.VK_PIPELINE_STAGE_2_BOTTOM_OF_PIPE_BIT,
            c.VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT,
            0,
        );

        if (c.VK_SUCCESS != self.lib.device.vkEndCommandBuffer(command_buffer.handle)) return error.EndCommandBuffer;

        const wait = [_]c.VkPipelineStageFlags{
            c.VK_PIPELINE_STAGE_2_TOP_OF_PIPE_BIT,
        };

        const semaphores: []const c.VkSemaphore = &.{ swapchain_semaphore.handle, command_buffer.semaphore.handle };

        const info = c.VkSubmitInfo{
            .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = semaphores.ptr,
            .pWaitDstStageMask = &wait,
            .commandBufferCount = 1,
            .pCommandBuffers = &command_buffer.handle,
            .signalSemaphoreCount = 1,
            .pSignalSemaphores = &command_buffer.semaphore.handle,
        };

        const swapchain_fence = self.swapchain.fences[image];

        if (c.VK_SUCCESS != self.lib.device.vkQueueSubmit(self.device.queue, 1, &info, swapchain_fence.handle)) return error.SubmitQueue;

        const present_info = c.VkPresentInfoKHR{
            .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = &command_buffer.semaphore.handle,
            .swapchainCount = 1,
            .pSwapchains = &self.swapchain.handle,
            .pImageIndices = &image,
        };

        if (c.VK_SUCCESS != self.lib.device.vkQueuePresentKHR(self.device.queue, &present_info)) return error.PresentQueue;
    }
};

// pub const Manager = struct {
//     fences: []c.VkFence,
//     acquire_semaphores: []c.VkSemaphore,
//     release_semaphores: []c.VkSemaphore,

//     descriptor_pool: c.VkDescriptorPool,
//     descriptor_sets: []DescriptorSet,
//     descriptor_set_count: u32,

//     pub fn init(self: *Manager, library: *Library, device: Device, allocator: *Allocator) !void {
//         const fence_info = c.VkFenceCreateInfo{
//             .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
//             .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
//         };

//         const command_info = c.VkCommandBufferAllocateInfo{
//             .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
//             .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
//             .commandPool = self.command_pool,
//             .commandBufferCount = MAX_FRAMES,
//         };

//         const semaphore_info = c.VkSemaphoreCreateInfo{
//             .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
//         };

//         self.fences = try allocator.main.alloc(c.VkFence, MAX_FRAMES);
//         self.acquire_semaphores = try allocator.main.alloc(c.VkSemaphore, MAX_FRAMES + 1);
//         self.release_semaphores = try allocator.main.alloc(c.VkSemaphore, MAX_FRAMES);

//         for (0..MAX_FRAMES) |i| {
//             if (c.VK_SUCCESS != library.device.vkCreateFence(device.handle, &fence_info, null, &self.fences[i])) return error.Fence;
//             if (c.VK_SUCCESS != library.device.vkCreateSemaphore(device.handle, &semaphore_info, null, &self.acquire_semaphores[i])) return error.Semaphore;
//             if (c.VK_SUCCESS != library.device.vkCreateSemaphore(device.handle, &semaphore_info, null, &self.release_semaphores[i])) return error.Semaphore;
//         }

//         if (c.VK_SUCCESS != library.device.vkCreateSemaphore(device.handle, &semaphore_info, null, &self.acquire_semaphores[MAX_FRAMES])) return error.Semaphore;

//         const descriptor_count: u32 = 10;
//         self.descriptor_sets = try allocator.main.alloc(DescriptorSet, descriptor_count);
//         self.descriptor_set_count = 0;

//         const descriptor_pool_sizes = &[_]c.VkDescriptorPoolSize{
//             .{
//                 .type = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
//                 .descriptorCount = descriptor_count,
//             },
//             .{
//                 .type = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
//                 .descriptorCount = descriptor_count,
//             },
//         };

//         const descriptor_pool_info = c.VkDescriptorPoolCreateInfo{
//             .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
//             .poolSizeCount = @intCast(descriptor_pool_sizes.len),
//             .pPoolSizes = descriptor_pool_sizes.ptr,
//             .maxSets = 10,
//         };

//         self.descriptor_pool = undefined;

//         if (c.VK_SUCCESS != library.device.vkCreateDescriptorPool(device.handle, &descriptor_pool_info, null, &self.descriptor_pool)) return error.DescriptorPool;
//     }

//     pub fn addDescriptorSet(self: *Manager, library: *Library, device: Device, layout: DescriptorSetLayout) !u32 {
//         if (self.descriptor_set_count >= 10) return error.OutOfDescriptors;
//         defer self.descriptor_set_count += 1;

//         const index = self.descriptor_set_count;
//         const descriptor_set = &self.descriptor_sets[index];
//         const allocate_info = c.VkDescriptorSetAllocateInfo{
//             .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
//             .descriptorPool = self.descriptor_pool,
//             .descriptorSetCount = 1,
//             .pSetLayouts = &layout.handle,
//         };

//         descriptor_set.layout = layout;
//         if (c.VK_SUCCESS != library.device.vkAllocateDescriptorSets(device.handle, &allocate_info, &descriptor_set.handle)) return error.OutOfDescriptors;

//         return index;
//     }

//     pub fn updateDescriptorSet(self: *Manager, library: *Library, device: Device, index: u32, binding: u32, range: Buffer.Range) !void {
//         const buffer_info = c.VkDescriptorBufferInfo{
//             .buffer = range.handle,
//             .range = range.size,
//             .offset = range.offset,
//         };

//         const set = self.descriptor_sets[index];
//         const write_set = c.VkWriteDescriptorSet{
//             .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
//             .dstSet = set.handle,
//             .dstBinding = binding,
//             .descriptorCount = 1,
//             .descriptorType = set.layout.bindings[binding].descriptorType,
//             .pBufferInfo = &buffer_info,
//         };

//         library.device.vkUpdateDescriptorSets(device.handle, 1, &write_set, 0, null);
//     }
// };

fn transitionImage(context: *Context, command_buffer: *Command.Buffer, image: c.VkImage, old_layout: c.VkImageLayout, new_layout: c.VkImageLayout, src_stage: c.VkPipelineStageFlags2, dst_stage: c.VkPipelineStageFlags2, src_access: c.VkAccessFlags2, dst_access: c.VkAccessFlags2) void {
    const barrier = c.VkImageMemoryBarrier2{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2,
        .srcStageMask = src_stage,
        .dstStageMask = dst_stage,
        .srcAccessMask = src_access,
        .dstAccessMask = dst_access,
        .oldLayout = old_layout,
        .newLayout = new_layout,
        .image = image,
        .srcQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED,
        .dstQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED,
        .subresourceRange = .{
            .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
            .baseMipLevel = 0,
            .levelCount = 1,
            .baseArrayLayer = 0,
            .layerCount = 1,
        },
    };

    const dependency_info = c.VkDependencyInfo{
        .sType = c.VK_STRUCTURE_TYPE_DEPENDENCY_INFO,
        .dependencyFlags = 0,
        .imageMemoryBarrierCount = 1,
        .pImageMemoryBarriers = &barrier,
    };

    context.lib.device.vkCmdPipelineBarrier2(command_buffer.handle, &dependency_info);
}

const std = @import("std");
const c = @import("Util").c;

const Allocator = @import("Util").Allocator;
const Matrix = @import("Util").Matrix(4);

pub const Instance = @import("Instance.zig").Instance;
pub const Surface = @import("Surface.zig").Surface;
pub const Buffer = @import("Buffer.zig").Buffer;
pub const Device = @import("Device.zig").Device;
pub const Pipeline = @import("Pipeline.zig").Pipeline;
pub const Swapchain = @import("Swapchain.zig").Swapchain;
pub const Command = @import("Command.zig").Command;
pub const Input = @import("Shader.zig").Input;
pub const Semaphores = @import("Sync.zig").Semaphores;
pub const Fences = @import("Sync.zig").Fences;
pub const RenderGroup = @import("Render.zig").RenderGroup;
pub const Descriptor = @import("Shader.zig").Descriptor;
