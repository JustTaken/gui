const VALIDATION_LAYERS: []const [*c]const u8 = &.{
    "VK_LAYER_KHRONOS_validation",
};

const INSTANCE_EXTENSIONS: []const [*c]const u8 = &.{
    "VK_KHR_surface",
    "VK_KHR_wayland_surface",
};

pub const Instance = struct {
    handle: c.VkInstance,

    pub fn init(self: *Instance, context: *Context) !void {
        var layer_count: u32 = 0;

        if (c.VK_SUCCESS != context.lib.pfn.vkEnumerateInstanceLayerProperties(&layer_count, null)) return error.EnumerateInstanceLayerProperties;
        const layers = try context.allocator.tmp.alloc(c.VkLayerProperties, layer_count);
        if (c.VK_SUCCESS != context.lib.pfn.vkEnumerateInstanceLayerProperties(&layer_count, layers.ptr)) return error.EnumerateInstanceLayerProperties;

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

        if (c.VK_SUCCESS != context.lib.pfn.vkCreateInstance(&create_info, null, &self.handle)) {
            return error.CreateInstance;
        }

        try context.lib.load_instance(self.handle);
    }
};

const std = @import("std");
const c = @import("Util").c;
const Context = @import("Lib.zig").Context;
