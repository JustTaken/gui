pub const Swapchain = struct {
    handle: c.VkSwapchainKHR,
    images: []c.VkImage,
    image_views: []c.VkImageView,
    image_count: u32,
    command_buffers: []Command.Buffer,
    surface_format: c.VkSurfaceFormatKHR,
    present_mode: c.VkPresentModeKHR,
    extent: c.VkExtent2D,
    suboptimal: bool,

    semaphores: []*Semaphore,
    fences: []*Fence,
    extra_semaphore: *Semaphore,

    const INITIAL_SIZE: u32 = 10;

    pub fn startup(self: *Swapchain, context: *Context, width: u32, height: u32) !void {
        self.images = try context.allocator.main.alloc(c.VkImage, INITIAL_SIZE);
        self.image_views = try context.allocator.main.alloc(c.VkImageView, INITIAL_SIZE);

        self.semaphores = try context.allocator.main.alloc(*Semaphore, INITIAL_SIZE);
        self.fences = try context.allocator.main.alloc(*Fence, INITIAL_SIZE);

        self.suboptimal = false;

        @memset(self.images, null);
        @memset(self.image_views, null);

        for (0..INITIAL_SIZE) |i| {
            self.semaphores[i] = try context.semaphores.add(context);
            self.fences[i] = try context.fences.add(context);
        }

        self.extra_semaphore = try context.semaphores.add(context);

        self.handle = null;
        self.present_mode = c.VK_PRESENT_MODE_FIFO_KHR;
        self.extent.width = 0;
        self.extent.height = 0;

        var format_count: u32 = 0;

        if (c.VK_SUCCESS != context.lib.instance.vkGetPhysicalDeviceSurfaceFormatsKHR(context.device.physical, context.surface.handle, &format_count, null)) return error.SurfaceFormats;

        const formats = try context.allocator.tmp.alloc(c.VkSurfaceFormatKHR, format_count);
        defer context.allocator.tmp.free(formats);

        if (c.VK_SUCCESS != context.lib.instance.vkGetPhysicalDeviceSurfaceFormatsKHR(context.device.physical, context.surface.handle, &format_count, formats.ptr)) return error.SurfaceFormats;

        const preferreds: []const c.VkFormat = &.{
            c.VK_FORMAT_R8G8B8A8_SRGB,
        };

        self.surface_format = outer: for (preferreds) |preferred| {
            for (formats) |format| {
                if (preferred == format.format) break :outer format;
            }
        } else return error.SurfaceFormat;

        try self.new(context, width, height);
    }

    pub fn new(self: *Swapchain, context: *Context, width: u32, height: u32) !void {
        self.extent = c.VkExtent2D{
            .width = width,
            .height = height,
        };

        var surface_capabilities: c.VkSurfaceCapabilitiesKHR = undefined;
        if (c.VK_SUCCESS != context.lib.instance.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(context.device.physical, context.surface.handle, &surface_capabilities)) return error.SurfaceCapabilities;

        const image_exced = surface_capabilities.maxImageCount > 0 and self.image_count > surface_capabilities.maxImageCount;
        self.image_count = if (image_exced) surface_capabilities.maxImageCount + 1 else surface_capabilities.minImageCount + 1;

        const transform = switch (surface_capabilities.supportedTransforms & c.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR) {
            0 => surface_capabilities.currentTransform,
            else => c.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
        };

        var composite: c.VkCompositeAlphaFlagBitsKHR = 0;

        if (surface_capabilities.supportedCompositeAlpha & c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR != 0) {
            composite = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
        } else if (surface_capabilities.supportedCompositeAlpha & c.VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR != 0) {
            composite = c.VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR;
        } else if (surface_capabilities.supportedCompositeAlpha & c.VK_COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR != 0) {
            composite = c.VK_COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR;
        } else if (surface_capabilities.supportedCompositeAlpha & c.VK_COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR != 0) {
            composite = c.VK_COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR;
        }

        const old_handle = self.handle;
        const info = c.VkSwapchainCreateInfoKHR{
            .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .surface = context.surface.handle,
            .minImageCount = self.image_count,
            .imageFormat = self.surface_format.format,
            .imageColorSpace = self.surface_format.colorSpace,
            .imageExtent = self.extent,
            .presentMode = self.present_mode,
            .imageArrayLayers = 1,
            .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
            .preTransform = transform,
            .compositeAlpha = composite,
            .clipped = c.VK_TRUE,
            .oldSwapchain = old_handle,
        };

        for (0..INITIAL_SIZE) |i| {
            if (self.image_views[i] == null) continue;

            context.lib.device.vkDestroyImageView(context.device.handle, self.image_views[i], null);
        }

        @memset(self.images, null);
        @memset(self.image_views, null);

        if (c.VK_SUCCESS != context.lib.device.vkCreateSwapchainKHR(context.device.handle, &info, null, &self.handle)) return error.SwapchainCreate;

        if (c.VK_SUCCESS != context.lib.device.vkGetSwapchainImagesKHR(context.device.handle, self.handle, &self.image_count, self.images.ptr)) return error.SwapchainImage;

        for (0..self.image_count) |i| {
            const subresource = c.VkImageSubresourceRange{
                .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0,
                .levelCount = 1,
                .baseArrayLayer = 0,
                .layerCount = 1,
            };

            const view_info = c.VkImageViewCreateInfo{
                .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                .image = self.images[i],
                .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
                .format = self.surface_format.format,
                .subresourceRange = subresource,
            };

            if (c.VK_SUCCESS != context.lib.device.vkCreateImageView(context.device.handle, &view_info, null, &self.image_views[i])) return error.CreateImageView;
        }

        self.command_buffers = try context.command_allocator.alloc(context, self.image_count);

        if (old_handle != null) {
            if (c.VK_SUCCESS != context.lib.device.vkQueueWaitIdle(context.device.queue)) return error.WaitQueue;
            context.lib.device.vkDestroySwapchainKHR(context.device.handle, old_handle, null);
        }
    }

    pub fn nextImage(self: *Swapchain, context: *Context) !u32 {
        if (self.suboptimal) {
            try self.new(context, self.extent.width, self.extent.height);
        }

        var image: u32 = 0;
        const semaphore = self.extra_semaphore;

        const result = context.lib.device.vkAcquireNextImageKHR(context.device.handle, self.handle, 1000000, semaphore.handle, null, &image);

        switch (result) {
            c.VK_SUCCESS => {},
            c.VK_SUBOPTIMAL_KHR => self.suboptimal = true,
            else => return error.AcquireImage,
        }

        self.extra_semaphore = self.semaphores[image];
        self.semaphores[image] = semaphore;

        const fence = self.fences[image];

        if (c.VK_SUCCESS != context.lib.device.vkWaitForFences(context.device.handle, 1, &fence.handle, c.VK_TRUE, 1000000)) return error.FenceWait;
        if (c.VK_SUCCESS != context.lib.device.vkResetFences(context.device.handle, 1, &fence.handle)) return error.FenceReset;

        return image;
    }
};

const std = @import("std");
const c = @import("Util").c;

const Context = @import("Lib.zig").Context;
const Allocator = @import("Util").Allocator;
const Render = @import("Render.zig").RenderGroup;
const Semaphore = @import("Sync.zig").Semaphores.Child;
const Fence = @import("Sync.zig").Fences.Child;

const Command = @import("Command.zig").Command;
