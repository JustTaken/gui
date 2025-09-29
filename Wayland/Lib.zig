pub const Wayland = struct {
    handle: Handle,

    const Handle = WaylandHandle;

    pub fn init(self: *Wayland) !void {
        try self.handle.connect();
    }

    pub fn dispatch(self: *Wayland) !void {
        try self.handle.dispatch();
    }

    pub fn setListener(self: *Wayland, ptr: *anyopaque, vtable: VTable) void {
        self.handle.listener_ptr = ptr;
        self.handle.vtable = vtable;
    }

    pub fn deinit(self: *Wayland) void {
        self.handle.disconnect();
    }
};

const VTable = struct {
    resize: *const fn (*anyopaque, width: u32, height: u32) void,
};

const WaylandHandle = struct {
    display: ?*c.wl_display = null,
    registry: ?*c.wl_registry = null,
    compositor: ?*c.wl_compositor = null,
    surface: ?*c.wl_surface = null,
    shm: ?*c.wl_shm = null,
    xdg_base: ?*c.xdg_wm_base = null,
    xdg_surface: ?*c.xdg_surface = null,
    xdg_toplevel: ?*c.xdg_toplevel = null,
    running: bool,

    listener_ptr: ?*anyopaque,
    vtable: VTable,

    fn connect(self: *WaylandHandle) !void {
        self.listener_ptr = null;

        self.display = c.wl_display_connect(null) orelse return error.Connect;
        self.registry = c.wl_display_get_registry(self.display) orelse return error.GetRegistry;

        _ = c.wl_registry_add_listener(self.registry, &registry_listener, self);
        _ = c.wl_display_roundtrip(self.display);

        self.surface = c.wl_compositor_create_surface(self.compositor) orelse return error.Surface;
        self.xdg_surface = c.xdg_wm_base_get_xdg_surface(self.xdg_base, self.surface) orelse return error.XdgSurface;

        _ = c.xdg_surface_add_listener(self.xdg_surface, &xdg_surface_listener, self);

        self.xdg_toplevel = c.xdg_surface_get_toplevel(self.xdg_surface) orelse return error.XdgToplevel;
        _ = c.xdg_toplevel_add_listener(self.xdg_toplevel, &xdg_toplevel_listener, self);

        c.wl_surface_commit(self.surface);
        self.running = true;
    }

    fn dispatch(self: *WaylandHandle) !void {
        if (c.wl_display_dispatch(self.display) == 0) return error.WaylandDispacth;
        if (!self.running) return error.Stop;
    }

    fn disconnect(self: *WaylandHandle) void {
        c.wl_display_disconnect(self.display);
    }
};

const registry_listener = c.wl_registry_listener{
    .global = registry_handle_global,
    .global_remove = registry_handle_global_remove,
};

const buffer_listener = c.wl_buffer_listener{
    .release = buffer_release,
};

const xdg_base_listener = c.xdg_wm_base_listener{
    .ping = base_ping,
};

const xdg_surface_listener = c.xdg_surface_listener{
    .configure = surface_configure,
};

const xdg_toplevel_listener = c.xdg_toplevel_listener{
    .configure = toplevel_configure,
    .close = toplevel_close,
    .configure_bounds = toplevel_configure_bounds,
    .wm_capabilities = toplevel_wm_capabilities,
};

// fn draw(wayland: *WaylandHandle) void {
//     const name = "/wl_shm_Gui";
//     const flags = std.c.O{ .CREAT = true, .ACCMODE = .RDWR, .EXCL = true };
//     const fd = std.c.shm_open(name, @bitCast(flags), 600);

//     if (fd > 0) {
//         if (std.c.shm_unlink(name) != 0) @panic("FAILED TO UNLINK SHARED MEMORY");
//     } else {
//         @panic("FAILED TO OPEN SHARED MEMORY");
//     }

//     const stride = wayland.width * wayland.channels;
//     const size = wayland.height * stride;
//     _ = std.c.ftruncate(fd, size);

//     const data = std.c.mmap(null, size, std.c.PROT.READ | std.c.PROT.WRITE, std.c.MAP{ .TYPE = .SHARED }, fd, 0);
//     const pool = c.wl_shm_create_pool(wayland.shm, fd, @intCast(size));
//     const buffer = c.wl_shm_pool_create_buffer(pool, 0, @intCast(wayland.width), @intCast(wayland.height), @intCast(stride), c.WL_SHM_FORMAT_XRGB8888);

//     c.wl_shm_pool_destroy(pool);
//     _ = std.c.close(fd);
//     {
//         const pixels: [*]u32 = @ptrCast(@alignCast(data));

//         const w = wayland.width / 3;
//         for (0..wayland.height) |i| {
//             for (0..wayland.width) |j| {
//                 const ww: u5 = @truncate(j / w);
//                 const color = (@as(u32, 0xFF) << (ww * 8));

//                 pixels[i * wayland.width + j] = 0xFF000000 | color;
//             }
//         }

//         _ = std.c.munmap(@alignCast(data), size);
//     }

//     _ = c.wl_buffer_add_listener(buffer, &buffer_listener, wayland);

//     c.wl_surface_attach(wayland.surface, buffer, 0, 0);
// }

fn surface_configure(data: ?*anyopaque, surface: ?*c.xdg_surface, serial: u32) callconv(.c) void {
    const wayland: *WaylandHandle = @ptrCast(@alignCast(data.?));
    c.xdg_surface_ack_configure(surface, serial);
    c.wl_surface_commit(wayland.surface);

    //draw(wayland);
}

fn buffer_release(data: ?*anyopaque, buffer: ?*c.wl_buffer) callconv(.c) void {
    _ = data;
    c.wl_buffer_destroy(buffer);
}

fn base_ping(data: ?*anyopaque, base: ?*c.xdg_wm_base, serial: u32) callconv(.c) void {
    _ = data;
    c.xdg_wm_base_pong(base, serial);
}

fn toplevel_configure(data: ?*anyopaque, toplevel: ?*c.xdg_toplevel, width: i32, height: i32, array: [*c]c.wl_array) callconv(.c) void {
    const wayland: *WaylandHandle = @ptrCast(@alignCast(data.?));

    if (width != 0 and height != 0) {
        if (wayland.listener_ptr) |ptr| {
            wayland.vtable.resize(ptr, @intCast(width), @intCast(height));
        }
    }

    _ = array;
    _ = toplevel;
}

fn toplevel_close(data: ?*anyopaque, toplevel: ?*c.xdg_toplevel) callconv(.c) void {
    const wayland: *WaylandHandle = @ptrCast(@alignCast(data.?));
    wayland.running = false;

    _ = toplevel;
}

fn toplevel_configure_bounds(data: ?*anyopaque, toplevel: ?*c.xdg_toplevel, width: i32, height: i32) callconv(.c) void {
    _ = data;
    _ = toplevel;
    _ = width;
    _ = height;
}

fn toplevel_wm_capabilities(data: ?*anyopaque, toplevel: ?*c.xdg_toplevel, capabilities: [*c]c.wl_array) callconv(.c) void {
    _ = data;
    _ = toplevel;
    _ = capabilities;
}

fn registry_handle_global(data: ?*anyopaque, registry: ?*c.wl_registry, name: u32, interface: [*c]const u8, version: u32) callconv(.c) void {
    const wayland: *WaylandHandle = @ptrCast(@alignCast(data.?));

    const interface_name: []const u8 = std.mem.span(@as([*:0]const u8, interface));

    if (std.mem.eql(u8, interface_name, std.mem.span(@as([*:0]const u8, c.wl_compositor_interface.name)))) {
        const ptr = c.wl_registry_bind(registry, name, &c.wl_compositor_interface, version);
        wayland.compositor = @ptrCast(@alignCast(ptr.?));
    } else if (std.mem.eql(u8, interface_name, std.mem.span(@as([*:0]const u8, c.wl_shm_interface.name)))) {
        const ptr = c.wl_registry_bind(registry, name, &c.wl_shm_interface, version);
        wayland.shm = @ptrCast(@alignCast(ptr.?));
    } else if (std.mem.eql(u8, interface_name, std.mem.span(@as([*:0]const u8, c.xdg_wm_base_interface.name)))) {
        const ptr = c.wl_registry_bind(registry, name, &c.xdg_wm_base_interface, version);
        wayland.xdg_base = @ptrCast(@alignCast(ptr.?));

        _ = c.xdg_wm_base_add_listener(wayland.xdg_base, &xdg_base_listener, wayland);
    }
}

fn registry_handle_global_remove(data: ?*anyopaque, registry: ?*c.wl_registry, name: u32) callconv(.c) void {
    _ = data;
    _ = registry;
    _ = name;
}

const std = @import("std");
const c = @import("Util").c;
const Allocator = @import("Util").Allocator;
