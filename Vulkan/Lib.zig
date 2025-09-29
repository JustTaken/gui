const VALIDATION_LAYERS: []const [*c]const u8 = &.{
    "VK_LAYER_KHRONOS_validation",
};

const INSTANCE_EXTENSIONS: []const [*c]const u8 = &.{
    "VK_KHR_surface",
    "VK_KHR_wayland_surface",
};

const DEVICE_EXTENSIONS: []const [*c]const u8 = &.{
    "VK_KHR_swapchain",
};

const MAX_FRAMES: u32 = 10;

const LibraryPointers = struct {
    vkEnumerateInstanceLayerProperties: @typeInfo(c.PFN_vkEnumerateInstanceLayerProperties).optional.child,
    vkCreateInstance: @typeInfo(c.PFN_vkCreateInstance).optional.child,
    vkGetInstanceProcAddr: @typeInfo(c.PFN_vkGetInstanceProcAddr).optional.child,

    fn load(library: *Library) !void {
        inline for (@typeInfo(LibraryPointers).@"struct".fields) |field| {
            if (library.handle.lookup(field.type, field.name)) |ptr| {
                @field(&library.pfn, field.name) = @ptrCast(ptr);
            } else {
                std.debug.print("Missing  symbol: {s}\n", .{field.name});
                return error.LibrarySymbol;
            }
        }
    }
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

    fn load(library: *Library, instance: c.VkInstance) !void {
        inline for (@typeInfo(InstancePointers).@"struct".fields) |field| {
            if (library.pfn.vkGetInstanceProcAddr(instance, field.name)) |ptr| {
                @field(&library.instance, field.name) = @ptrCast(ptr);
            } else {
                std.debug.print("Missing  symbol: {s}\n", .{field.name});
                return error.LibrarySymbol;
            }
        }
    }
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

    fn load(library: *Library, device: c.VkDevice) !void {
        inline for (@typeInfo(DevicePointers).@"struct".fields) |field| {
            if (library.instance.vkGetDeviceProcAddr(device, field.name)) |ptr| {
                @field(&library.device, field.name) = @ptrCast(ptr);
            } else {
                std.debug.print("Missing  symbol: {s}\n", .{field.name});
                return error.LibrarySymbol;
            }
        }
    }
};

pub const Library = struct {
    handle: std.DynLib,
    pfn: LibraryPointers = undefined,
    instance: InstancePointers = undefined,
    device: DevicePointers = undefined,

    pub fn init(self: *Library) !void {
        self.handle = std.DynLib.open("libvulkan.so") catch return error.VulkanLibrary;

        try LibraryPointers.load(self);
    }
};

pub const Instance = struct {
    handle: c.VkInstance,

    pub fn init(self: *Instance, library: *Library, allocator: *Allocator) !void {
        var layer_count: u32 = 0;

        _ = library.pfn.vkEnumerateInstanceLayerProperties(&layer_count, null);
        const layers = try allocator.tmp.alloc(c.VkLayerProperties, layer_count);
        _ = library.pfn.vkEnumerateInstanceLayerProperties(&layer_count, layers.ptr);

        for (VALIDATION_LAYERS) |required| {
            for (layers) |layer| {
                const lay = @as([*c]const u8, &layer.layerName);
                if (std.mem.eql(u8, std.mem.span(required), std.mem.span(lay))) break;
            } else return error.ValidationLayer;
        }

        const application_info = c.VkApplicationInfo{
            .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pApplicationName = "Hello triangle",
            .applicationVersion = c.VK_MAKE_VERSION(0, 0, 1),
            .pEngineName = "No Engine",
            .engineVersion = c.VK_MAKE_VERSION(0, 0, 1),
            .apiVersion = c.VK_MAKE_VERSION(1, 4, 3),
        };

        const create_info = c.VkInstanceCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pApplicationInfo = &application_info,
            .enabledLayerCount = @intCast(VALIDATION_LAYERS.len),
            .ppEnabledLayerNames = &VALIDATION_LAYERS[0],
            .enabledExtensionCount = @intCast(INSTANCE_EXTENSIONS.len),
            .ppEnabledExtensionNames = &INSTANCE_EXTENSIONS[0],
        };

        if (c.VK_SUCCESS != library.pfn.vkCreateInstance(&create_info, null, &self.handle)) {
            return error.CreateInstance;
        }

        try InstancePointers.load(library, self.handle);
    }
};

pub const Surface = struct {
    handle: c.VkSurfaceKHR,

    pub fn init(self: *Surface, library: *Library, instance: Instance, display: ?*c.wl_display, surface: ?*c.wl_surface) !void {
        const info = c.VkWaylandSurfaceCreateInfoKHR{
            .sType = c.VK_STRUCTURE_TYPE_WAYLAND_SURFACE_CREATE_INFO_KHR,
            .flags = 0,
            .display = display,
            .surface = surface,
        };

        if (c.VK_SUCCESS != library.instance.vkCreateWaylandSurfaceKHR(instance.handle, &info, null, &self.handle)) return error.SurfaceCreate;
    }
};

pub const Device = struct {
    handle: c.VkDevice,
    surface: Surface,
    physical: c.VkPhysicalDevice,
    family_index: u32,
    queue: c.VkQueue,
    memory_properties: c.VkPhysicalDeviceMemoryProperties,

    pub fn init(self: *Device, library: *Library, instance: Instance, surface: Surface, allocator: *Allocator) !void {
        self.surface = surface;

        var device_count: u32 = 0;
        _ = library.instance.vkEnumeratePhysicalDevices(instance.handle, &device_count, null);

        const devices = try allocator.tmp.alloc(c.VkPhysicalDevice, device_count);
        defer allocator.tmp.free(devices);

        _ = library.instance.vkEnumeratePhysicalDevices(instance.handle, &device_count, devices.ptr);

        var physical_device_points: u8 = 0xFF;

        for (devices) |device| {
            var properties: c.VkPhysicalDeviceProperties = undefined;
            library.instance.vkGetPhysicalDeviceProperties(device, &properties);

            if (properties.apiVersion < c.VK_API_VERSION_1_3) {
                continue;
            }

            var family_count: u32 = 0;
            _ = library.instance.vkGetPhysicalDeviceQueueFamilyProperties(device, &family_count, null);

            const family_properties = try allocator.tmp.alloc(c.VkQueueFamilyProperties, family_count);
            defer allocator.tmp.free(family_properties);

            _ = library.instance.vkGetPhysicalDeviceQueueFamilyProperties(device, &family_count, family_properties.ptr);

            var index: u32 = 0;
            for (family_properties, 0..) |propertie, i| {
                var present = c.VK_FALSE;
                _ = library.instance.vkGetPhysicalDeviceSurfaceSupportKHR(device, @intCast(i), self.surface.handle, &present);

                if (present == 0) continue;
                if (propertie.queueFlags & c.VK_QUEUE_GRAPHICS_BIT == 0) continue;

                index = @intCast(i);

                break;
            } else continue;

            const points: u8 = switch (properties.deviceType) {
                c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU => 1,
                c.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU => 2,
                c.VK_PHYSICAL_DEVICE_TYPE_CPU => 3,
                c.VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU => 4,
                else => 5,
            };

            if (points < physical_device_points) {
                physical_device_points = points;
                self.physical = device;
                self.family_index = index;
            }
        }

        library.instance.vkGetPhysicalDeviceMemoryProperties(self.physical, &self.memory_properties);

        var extension_count: u32 = 0;
        _ = library.instance.vkEnumerateDeviceExtensionProperties(self.physical, null, &extension_count, null);

        const extensions = try allocator.tmp.alloc(c.VkExtensionProperties, extension_count);
        defer allocator.tmp.free(extensions);

        _ = library.instance.vkEnumerateDeviceExtensionProperties(self.physical, null, &extension_count, extensions.ptr);

        for (DEVICE_EXTENSIONS) |required| {
            for (extensions) |extension| {
                const ext = @as([*c]const u8, &extension.extensionName);
                if (std.mem.eql(u8, std.mem.span(required), std.mem.span(ext))) break;
            } else return error.DeviceExtension;
        }

        var query_device_dynamic_state = c.VkPhysicalDeviceExtendedDynamicStateFeaturesEXT{
            .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_EXTENDED_DYNAMIC_STATE_FEATURES_EXT,
        };

        var query_device_features_1_3 = c.VkPhysicalDeviceVulkan13Features{
            .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
            .pNext = &query_device_dynamic_state,
        };

        var query_device_features = c.VkPhysicalDeviceFeatures2{
            .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2,
            .pNext = &query_device_features_1_3,
        };

        library.instance.vkGetPhysicalDeviceFeatures2(self.physical, &query_device_features);

        if (query_device_features_1_3.dynamicRendering != c.VK_TRUE) return error.DynamicRenderingFeature;
        if (query_device_features_1_3.synchronization2 != c.VK_TRUE) return error.SynchronizationFeature;
        if (query_device_dynamic_state.extendedDynamicState != c.VK_TRUE) return error.ExtendedDynamicStateFeature;

        query_device_features_1_3 = .{
            .sType = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
            .pNext = &query_device_dynamic_state,
            .synchronization2 = c.VK_TRUE,
            .dynamicRendering = c.VK_TRUE,
        };

        const queue_priority: f32 = 1.0;

        const queue_info = c.VkDeviceQueueCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = self.family_index,
            .queueCount = 1,
            .pQueuePriorities = &queue_priority,
        };

        const info = c.VkDeviceCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .pNext = &query_device_features,
            .queueCreateInfoCount = 1,
            .pQueueCreateInfos = &queue_info,
            .ppEnabledExtensionNames = &DEVICE_EXTENSIONS[0],
            .enabledExtensionCount = DEVICE_EXTENSIONS.len,
        };

        if (c.VK_SUCCESS != library.instance.vkCreateDevice(self.physical, &info, null, &self.handle)) return error.DeviceCreate;
        try DevicePointers.load(library, self.handle);

        library.device.vkGetDeviceQueue(self.handle, self.family_index, 0, &self.queue);
    }
};

pub const Manager = struct {
    command_pool: c.VkCommandPool,
    command_buffers: []c.VkCommandBuffer,

    fences: []c.VkFence,
    acquire_semaphores: []c.VkSemaphore,
    release_semaphores: []c.VkSemaphore,

    pub fn init(self: *Manager, library: *Library, device: Device, allocator: *Allocator) !void {
        const pool_info = c.VkCommandPoolCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .flags = c.VK_COMMAND_POOL_CREATE_TRANSIENT_BIT | c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            .queueFamilyIndex = device.family_index,
        };

        if (c.VK_SUCCESS != library.device.vkCreateCommandPool(device.handle, &pool_info, null, &self.command_pool)) return error.CommandPool;

        const fence_info = c.VkFenceCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
            .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
        };

        const command_info = c.VkCommandBufferAllocateInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandPool = self.command_pool,
            .commandBufferCount = MAX_FRAMES,
        };

        const semaphore_info = c.VkSemaphoreCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
        };

        self.command_buffers = try allocator.main.alloc(c.VkCommandBuffer, MAX_FRAMES);
        self.fences = try allocator.main.alloc(c.VkFence, MAX_FRAMES);
        self.acquire_semaphores = try allocator.main.alloc(c.VkSemaphore, MAX_FRAMES + 1);
        self.release_semaphores = try allocator.main.alloc(c.VkSemaphore, MAX_FRAMES);

        if (c.VK_SUCCESS != library.device.vkAllocateCommandBuffers(device.handle, &command_info, self.command_buffers.ptr)) return error.AllocateCommandBuffer;

        for (0..MAX_FRAMES) |i| {
            if (c.VK_SUCCESS != library.device.vkCreateFence(device.handle, &fence_info, null, &self.fences[i])) return error.Fence;
            if (c.VK_SUCCESS != library.device.vkCreateSemaphore(device.handle, &semaphore_info, null, &self.acquire_semaphores[i])) return error.Semaphore;
            if (c.VK_SUCCESS != library.device.vkCreateSemaphore(device.handle, &semaphore_info, null, &self.release_semaphores[i])) return error.Semaphore;
        }

        if (c.VK_SUCCESS != library.device.vkCreateSemaphore(device.handle, &semaphore_info, null, &self.acquire_semaphores[MAX_FRAMES])) return error.Semaphore;
    }
};

pub const Swapchain = struct {
    handle: c.VkSwapchainKHR,
    images: []c.VkImage,
    image_views: []c.VkImageView,
    image_count: u32,
    format: c.VkSurfaceFormatKHR,
    present_mode: c.VkPresentModeKHR,
    extent: c.VkExtent2D,

    pub fn startup(self: *Swapchain, library: *Library, device: Device, allocator: *Allocator) !void {
        self.images = try allocator.main.alloc(c.VkImage, MAX_FRAMES);
        self.image_views = try allocator.main.alloc(c.VkImageView, MAX_FRAMES);

        @memset(self.images, null);
        @memset(self.image_views, null);

        self.handle = null;
        self.present_mode = c.VK_PRESENT_MODE_FIFO_KHR;
        self.extent.width = 0;
        self.extent.height = 0;

        var format_count: u32 = 0;

        if (c.VK_SUCCESS != library.instance.vkGetPhysicalDeviceSurfaceFormatsKHR(device.physical, device.surface.handle, &format_count, null)) return error.SurfaceFormats;

        const formats = try allocator.tmp.alloc(c.VkSurfaceFormatKHR, format_count);
        defer allocator.tmp.free(formats);

        if (c.VK_SUCCESS != library.instance.vkGetPhysicalDeviceSurfaceFormatsKHR(device.physical, device.surface.handle, &format_count, formats.ptr)) return error.SurfaceFormats;

        const preferreds: []const c.VkFormat = &.{
            c.VK_FORMAT_R8G8B8A8_SRGB,
        };

        self.format = outer: for (preferreds) |preferred| {
            for (formats) |format| {
                if (preferred == format.format) break :outer format;
            }
        } else return error.SurfaceFormat;
    }

    pub fn new(self: *Swapchain, library: *Library, device: Device, width: u32, height: u32) !void {
        self.extent = c.VkExtent2D{
            .width = width,
            .height = height,
        };

        var surface_capabilities: c.VkSurfaceCapabilitiesKHR = undefined;
        if (c.VK_SUCCESS != library.instance.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device.physical, device.surface.handle, &surface_capabilities)) return error.SurfaceCapabilities;

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
            .surface = device.surface.handle,
            .minImageCount = self.image_count,
            .imageFormat = self.format.format,
            .imageColorSpace = self.format.colorSpace,
            .imageExtent = self.extent,
            .imageArrayLayers = 1,
            .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
            .preTransform = transform,
            .compositeAlpha = composite,
            .clipped = c.VK_TRUE,
            .oldSwapchain = old_handle,
        };

        for (0..MAX_FRAMES) |i| {
            if (self.image_views[i] == null) continue;

            library.device.vkDestroyImageView(device.handle, self.image_views[i], null);
        }

        @memset(self.images, null);
        @memset(self.image_views, null);

        if (c.VK_SUCCESS != library.device.vkCreateSwapchainKHR(device.handle, &info, null, &self.handle)) return error.SwapchainCreate;
        if (c.VK_SUCCESS != library.device.vkGetSwapchainImagesKHR(device.handle, self.handle, &self.image_count, self.images.ptr)) return error.SwapchainImage;

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
                .format = self.format.format,
                .subresourceRange = subresource,
            };

            if (c.VK_SUCCESS != library.device.vkCreateImageView(device.handle, &view_info, null, &self.image_views[i])) return error.CreateImageView;
        }

        if (old_handle != null) {
            if (c.VK_SUCCESS != library.device.vkQueueWaitIdle(device.queue)) return error.WaitQueue;
            library.device.vkDestroySwapchainKHR(device.handle, old_handle, null);
        }
    }

    pub fn nextImage(self: *Swapchain, library: *Library, device: Device, manager: *Manager) !u32 {
        var image: u32 = 0;

        const last_index = manager.acquire_semaphores.len - 1;
        const semaphore = manager.acquire_semaphores[last_index];

        if (c.VK_SUCCESS != library.device.vkAcquireNextImageKHR(device.handle, self.handle, 1000000, semaphore, null, &image)) return error.AcquireImage;

        manager.acquire_semaphores[last_index] = manager.acquire_semaphores[image];
        manager.acquire_semaphores[image] = semaphore;

        const fence = manager.fences[image];

        if (c.VK_SUCCESS != library.device.vkWaitForFences(device.handle, 1, &fence, c.VK_TRUE, 1000000)) return error.FenceWait;
        if (c.VK_SUCCESS != library.device.vkResetFences(device.handle, 1, &fence)) return error.FenceReset;

        return image;
    }

    pub fn renderToImage(self: *Swapchain, library: *Library, device: Device, pipeline: Pipeline, manager: *Manager, image: u32, T: type, vertices: Buffer(T), indices: Buffer(u16)) !void {
        const command_buffer = manager.command_buffers[image];
        const begin_info = c.VkCommandBufferBeginInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        };

        const clear_color = c.VkClearValue{
            .color = .{ .float32 = .{ 1.0, 1.0, 1.0, 1.0 } },
        };

        const color_attachment = c.VkRenderingAttachmentInfo{
            .sType = c.VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO,
            .imageView = self.image_views[image],
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
                .extent = self.extent,
            },
        };

        const viewport = c.VkViewport{
            .width = @floatFromInt(self.extent.width),
            .height = @floatFromInt(self.extent.height),
            .minDepth = 0.0,
            .maxDepth = 1.0,
        };

        const scissor = c.VkRect2D{
            .extent = self.extent,
        };

        const offset = [_]c.VkDeviceSize{0};

        if (c.VK_SUCCESS != library.device.vkBeginCommandBuffer(command_buffer, &begin_info)) return error.BeginCommandBuffer;

        transitionImage(
            library,
            command_buffer,
            self.images[image],
            c.VK_IMAGE_LAYOUT_UNDEFINED,
            c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
            c.VK_PIPELINE_STAGE_2_TOP_OF_PIPE_BIT,
            c.VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT,
            0,
            c.VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT,
        );

        library.device.vkCmdBeginRendering(command_buffer, &rendering_info);
        library.device.vkCmdBindPipeline(command_buffer, c.VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline.handle);
        library.device.vkCmdSetViewport(command_buffer, 0, 1, &viewport);
        library.device.vkCmdSetScissor(command_buffer, 0, 1, &scissor);
        library.device.vkCmdBindVertexBuffers(command_buffer, 0, 1, &vertices.handle, &offset);
        library.device.vkCmdBindIndexBuffer(command_buffer, indices.handle, 0, c.VK_INDEX_TYPE_UINT16);
        library.device.vkCmdDrawIndexed(command_buffer, indices.count, 1, 0, 0, 0);
        library.device.vkCmdEndRendering(command_buffer);

        transitionImage(
            library,
            command_buffer,
            self.images[image],
            c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
            c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
            c.VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT,
            c.VK_PIPELINE_STAGE_2_BOTTOM_OF_PIPE_BIT,
            c.VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT,
            0,
        );

        if (c.VK_SUCCESS != library.device.vkEndCommandBuffer(command_buffer)) return error.EndCommandBuffer;

        const wait = [_]c.VkPipelineStageFlags{
            c.VK_PIPELINE_STAGE_2_TOP_OF_PIPE_BIT,
        };

        const info = c.VkSubmitInfo{
            .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = &manager.acquire_semaphores[image],
            .pWaitDstStageMask = &wait,
            .commandBufferCount = 1,
            .pCommandBuffers = &command_buffer,
            .signalSemaphoreCount = 1,
            .pSignalSemaphores = &manager.release_semaphores[image],
        };

        if (c.VK_SUCCESS != library.device.vkQueueSubmit(device.queue, 1, &info, manager.fences[image])) return error.SubmitQueue;

        const present_info = c.VkPresentInfoKHR{
            .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = &manager.release_semaphores[image],
            .swapchainCount = 1,
            .pSwapchains = &self.handle,
            .pImageIndices = &image,
        };

        if (c.VK_SUCCESS != library.device.vkQueuePresentKHR(device.queue, &present_info)) return error.PresentQueue;
    }
};

pub const Pipeline = struct {
    handle: c.VkPipeline,

    pub fn init(self: *Pipeline, library: *Library, device: Device, format: c.VkFormat, T: type, allocator: *Allocator) !void {
        const layout_info = c.VkPipelineLayoutCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        };

        var layout: c.VkPipelineLayout = undefined;
        if (c.VK_SUCCESS != library.device.vkCreatePipelineLayout(device.handle, &layout_info, null, &layout)) return error.PipelineLayout;

        const vertex_data = try VertexData.init(&.{T}, allocator);

        const vertex_input = c.VkPipelineVertexInputStateCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
            .vertexBindingDescriptionCount = @intCast(vertex_data.bindings.len),
            .pVertexBindingDescriptions = vertex_data.bindings.ptr,
            .vertexAttributeDescriptionCount = @intCast(vertex_data.attributes.len),
            .pVertexAttributeDescriptions = vertex_data.attributes.ptr,
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

        const shader = &[_]c.VkPipelineShaderStageCreateInfo{
            .{
                .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                .stage = c.VK_SHADER_STAGE_VERTEX_BIT,
                .module = try createShaderModule(library, device, "Asset/Shader/Vertex.spv", allocator),
                .pName = "main",
            },
            .{
                .sType = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                .stage = c.VK_SHADER_STAGE_FRAGMENT_BIT,
                .module = try createShaderModule(library, device, "Asset/Shader/Fragment.spv", allocator),
                .pName = "main",
            },
        };

        const pipeline_rendering = c.VkPipelineRenderingCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO,
            .colorAttachmentCount = 1,
            .pColorAttachmentFormats = &format,
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
            .layout = layout,
            .renderPass = null,
            .subpass = 0,
        };

        if (c.VK_SUCCESS != library.device.vkCreateGraphicsPipelines(device.handle, null, 1, &info, null, &self.handle)) return error.PipelineCreate;

        for (shader) |s| {
            library.device.vkDestroyShaderModule(device.handle, s.module, null);
        }
    }
};

pub fn Buffer(T: type) type {
    return struct {
        handle: c.VkBuffer,
        memory: c.VkDeviceMemory,
        count: u32,

        const Self = @This();

        pub const BufferData = union(enum) {
            count: u32,
            data: []const T,
        };

        pub fn init(library: *Library, device: Device, usage: c.VkBufferUsageFlags, sharing_mode: c.VkSharingMode, data: BufferData) !Self {
            var self: Self = undefined;

            self.count = switch (data) {
                .count => |count| count,
                .data => |d| @intCast(d.len),
            };

            const buffer_size = @sizeOf(T) * self.count;
            const info = c.VkBufferCreateInfo{
                .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
                .flags = 0,
                .size = buffer_size,
                .usage = usage,
                .sharingMode = sharing_mode,
            };

            if (c.VK_SUCCESS != library.device.vkCreateBuffer(device.handle, &info, null, &self.handle)) return error.CreateBuffer;

            var memory_requirements: c.VkMemoryRequirements = undefined;
            library.device.vkGetBufferMemoryRequirements(device.handle, self.handle, &memory_requirements);

            const index = try findMemory(
                device,
                memory_requirements.memoryTypeBits,
                c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            );

            const alloc_info = c.VkMemoryAllocateInfo{
                .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
                .allocationSize = memory_requirements.size,
                .memoryTypeIndex = index,
            };

            if (c.VK_SUCCESS != library.device.vkAllocateMemory(device.handle, &alloc_info, null, &self.memory)) return error.AllocateMemory;
            if (c.VK_SUCCESS != library.device.vkBindBufferMemory(device.handle, self.handle, self.memory, 0)) return error.BindBuffer;

            switch (data) {
                .data => |d| {
                    const remap = try self.map(library, device);
                    @memcpy(remap[0..d.len], d);
                    self.unmap(library, device);
                },
                else => {},
            }

            return self;
        }

        fn map(self: *Self, library: *Library, device: Device) ![*]T {
            var data: [*]T = undefined;

            if (c.VK_SUCCESS != library.device.vkMapMemory(device.handle, self.memory, 0, self.count * @sizeOf(T), 0, @ptrCast(&data))) return error.MapMemory;

            return data;
        }

        fn unmap(self: *Self, library: *Library, device: Device) void {
            library.device.vkUnmapMemory(device.handle, self.memory);
        }

        fn findMemory(device: Device, type_filter: u32, properties: c.VkMemoryPropertyFlags) !u32 {
            for (0..device.memory_properties.memoryTypeCount) |i| {
                const index: u5 = @intCast(i);
                const base: u32 = 1;

                if (type_filter & (base << index) > 0) {
                    if (device.memory_properties.memoryTypes[i].propertyFlags & properties == properties) {
                        return index;
                    }
                }
            }

            return error.MemoryTypeIndex;
        }
    };
}

fn transitionImage(library: *Library, command_buffer: c.VkCommandBuffer, image: c.VkImage, old_layout: c.VkImageLayout, new_layout: c.VkImageLayout, src_stage: c.VkPipelineStageFlags2, dst_stage: c.VkPipelineStageFlags2, src_access: c.VkAccessFlags2, dst_access: c.VkAccessFlags2) void {
    const barrier = c.VkImageMemoryBarrier2{
        .sType = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2,
        .srcStageMask = src_stage,
        .dstStageMask = dst_stage,
        .srcAccessMask = src_access,
        .dstAccessMask = dst_access,
        .oldLayout = old_layout,
        .newLayout = new_layout,
        .srcQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED,
        .dstQueueFamilyIndex = c.VK_QUEUE_FAMILY_IGNORED,
        .image = image,
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

    library.device.vkCmdPipelineBarrier2(command_buffer, &dependency_info);
}

fn createShaderModule(library: *Library, device: Device, path: []const u8, allocator: *Allocator) !c.VkShaderModule {
    const file = try std.fs.cwd().openFile(path, .{});
    const size = try file.getEndPos();
    const buffer = try allocator.tmp.alloc(u8, size);
    const len = try file.readAll(buffer);

    if (len != size) return error.ReadFile;

    const data: [*]u32 = @ptrCast(@alignCast(buffer.ptr));

    const info = c.VkShaderModuleCreateInfo{
        .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = @intCast(size),
        .pCode = data,
    };

    var module: c.VkShaderModule = undefined;
    if (c.VK_SUCCESS != library.device.vkCreateShaderModule(device.handle, &info, null, &module)) return error.ShaderModule;

    return module;
}

const VertexData = struct {
    bindings: []c.VkVertexInputBindingDescription,
    attributes: []c.VkVertexInputAttributeDescription,

    fn init(Ts: []const type, allocator: *Allocator) !VertexData {
        var self: VertexData = undefined;

        self.bindings = try allocator.tmp.alloc(c.VkVertexInputBindingDescription, Ts.len);

        var count: u32 = 0;

        inline for (0..Ts.len) |i| {
            const T = Ts[i];

            self.bindings[i] = .{
                .binding = @intCast(i),
                .stride = @sizeOf(T),
                .inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX,
            };

            const FIELDS = @typeInfo(T).@"struct".fields;
            count += FIELDS.len;
        }

        var j: u32 = 0;
        var offset: u32 = 0;
        self.attributes = try allocator.tmp.alloc(c.VkVertexInputAttributeDescription, count);

        inline for (0..Ts.len) |i| {
            const T = Ts[i];
            const FIELDS = @typeInfo(T).@"struct".fields;

            inline for (FIELDS, 0..) |field, k| {
                self.attributes[j] = .{
                    .binding = @intCast(i),
                    .location = @intCast(k),
                    .format = getFormat(field.type),
                    .offset = offset,
                };

                offset += @sizeOf(field.type);
                j += 1;
            }
        }

        return self;
    }

    fn getSize(T: type) u32 {
        switch (@typeInfo(T)) {
            .float => |f| {
                std.debug.assert(f.bits == 32);
                return 4;
            },
            else => @panic("NOT SUPPORTED"),
        }
    }

    fn getFormat(T: type) c.VkFormat {
        switch (@typeInfo(T)) {
            .array => |a| {
                const size = getSize(a.child);
                _ = size;

                switch (a.len) {
                    1 => return c.VK_FORMAT_R32_SFLOAT,
                    2 => return c.VK_FORMAT_R32G32_SFLOAT,
                    3 => return c.VK_FORMAT_R32G32B32_SFLOAT,
                    4 => return c.VK_FORMAT_R32G32B32A32_SFLOAT,
                    else => @panic("NOT SUPPORTED"),
                }
            },
            else => @panic("NOT SUPPORTED"),
        }

        @panic("NOT SUPPORTED");
    }
};

const std = @import("std");
const c = @import("Util").c;
const Allocator = @import("Util").Allocator;
