const DEVICE_EXTENSIONS: []const [*c]const u8 = &.{
    "VK_KHR_swapchain",
};

pub const Device = struct {
    handle: c.VkDevice,
    physical: c.VkPhysicalDevice,
    family_index: u32,
    queue: c.VkQueue,
    memory_properties: c.VkPhysicalDeviceMemoryProperties,

    pub fn init(self: *Device, context: *Context) !void {
        var device_count: u32 = 0;
        if (c.VK_SUCCESS != context.lib.instance.vkEnumeratePhysicalDevices(context.instance.handle, &device_count, null)) return error.EnumeratePhysicalDevices;

        const devices = try context.allocator.tmp.alloc(c.VkPhysicalDevice, device_count);
        defer context.allocator.tmp.free(devices);

        if (c.VK_SUCCESS != context.lib.instance.vkEnumeratePhysicalDevices(context.instance.handle, &device_count, devices.ptr)) return error.EnumeratePhysicalDevices;

        var physical_device_points: u8 = 0;

        for (devices) |device| {
            var properties: c.VkPhysicalDeviceProperties = undefined;
            context.lib.instance.vkGetPhysicalDeviceProperties(device, &properties);

            if (properties.apiVersion < c.VK_API_VERSION_1_3) {
                continue;
            }

            var family_count: u32 = 0;
            context.lib.instance.vkGetPhysicalDeviceQueueFamilyProperties(device, &family_count, null);

            const family_properties = try context.allocator.tmp.alloc(c.VkQueueFamilyProperties, family_count);
            defer context.allocator.tmp.free(family_properties);

            context.lib.instance.vkGetPhysicalDeviceQueueFamilyProperties(device, &family_count, family_properties.ptr);

            var index: u32 = 0;
            for (family_properties, 0..) |propertie, i| {
                var present = c.VK_FALSE;
                if (c.VK_SUCCESS != context.lib.instance.vkGetPhysicalDeviceSurfaceSupportKHR(device, @intCast(i), context.surface.handle, &present)) return error.SurfaceSupport;

                if (present == 0) continue;
                if (propertie.queueFlags & c.VK_QUEUE_GRAPHICS_BIT == 0) continue;

                index = @intCast(i);

                break;
            } else continue;

            const points: u8 = switch (properties.deviceType) {
                c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU => 5,
                c.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU => 4,
                c.VK_PHYSICAL_DEVICE_TYPE_CPU => 3,
                c.VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU => 2,
                else => 1,
            };

            if (points > physical_device_points) {
                physical_device_points = points;
                self.physical = device;
                self.family_index = index;
            }
        }

        context.lib.instance.vkGetPhysicalDeviceMemoryProperties(self.physical, &self.memory_properties);

        var extension_count: u32 = 0;
        if (c.VK_SUCCESS != context.lib.instance.vkEnumerateDeviceExtensionProperties(self.physical, null, &extension_count, null)) return error.EnumerateExtensionProperties;

        const extensions = try context.allocator.tmp.alloc(c.VkExtensionProperties, extension_count);

        if (c.VK_SUCCESS != context.lib.instance.vkEnumerateDeviceExtensionProperties(self.physical, null, &extension_count, extensions.ptr)) return error.EnumeratExtensionPropertiese;

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

        context.lib.instance.vkGetPhysicalDeviceFeatures2(self.physical, &query_device_features);

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

        if (c.VK_SUCCESS != context.lib.instance.vkCreateDevice(self.physical, &info, null, &self.handle)) return error.DeviceCreate;
        try context.lib.load_device(self.handle);

        context.lib.device.vkGetDeviceQueue(self.handle, self.family_index, 0, &self.queue);
    }
};

const std = @import("std");
const c = @import("Util").c;
const Context = @import("Lib.zig").Context;
