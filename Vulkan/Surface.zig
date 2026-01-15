pub const Surface = struct {
    handle: c.VkSurfaceKHR,

    pub fn init(self: *Surface, context: *Context, display: ?*c.wl_display, surface: ?*c.wl_surface) !void {
        const info = c.VkWaylandSurfaceCreateInfoKHR{
            .sType = c.VK_STRUCTURE_TYPE_WAYLAND_SURFACE_CREATE_INFO_KHR,
            .flags = 0,
            .display = display,
            .surface = surface,
        };

        if (c.VK_SUCCESS != context.lib.instance.vkCreateWaylandSurfaceKHR(context.instance.handle, &info, null, &self.handle)) return error.SurfaceCreate;
    }
};

const std = @import("std");
const c = @import("Util").c;

const Context = @import("Lib.zig").Context;
