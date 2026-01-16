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

const Keymap = struct {
    context: *c.xkb_context,
    handle: *c.xkb_keymap,
    state: *c.xkb_state,

    fn init(self: *Keymap) void {
        self.context = c.xkb_context_new(c.XKB_CONTEXT_NO_FLAGS) orelse unreachable;
    }

    fn setKeymap(self: *Keymap, string: [*c]const u8) void {
        self.handle = c.xkb_keymap_new_from_string(self.context, string, c.XKB_KEYMAP_FORMAT_TEXT_V1, c.XKB_KEYMAP_COMPILE_NO_FLAGS,) orelse unreachable;
        self.state = c.xkb_state_new(self.handle) orelse unreachable;
    }

    fn setModifiers(self: *Keymap, depressed: u32, latched: u32, locked: u32, group: u32) void {
        const changed = c.xkb_state_update_mask(self.state, depressed, latched, locked, group, group, group);
        _ = changed;
    }

    fn getSym(self: *Keymap, code: u32) u32 {
        return c.xkb_state_key_get_one_sym(self.state, code);
    }

    fn deinit(self: *Keymap) void {
        c.xkb_state_unref(self.state);
        c.xkb_keymap_unref(self.handle);
        c.xkb_context_unref(self.context);
    }
};

const WaylandHandle = struct {
    display: ?*c.wl_display = null,
    registry: ?*c.wl_registry = null,
    compositor: ?*c.wl_compositor = null,
    surface: ?*c.wl_surface = null,
    seat: ?*c.wl_seat = null,
    keyboard: ?*c.wl_keyboard = null,
    xdg_base: ?*c.xdg_wm_base = null,
    xdg_surface: ?*c.xdg_surface = null,
    xdg_toplevel: ?*c.xdg_toplevel = null,
    keymap: Keymap,
    running: bool,

    listener_ptr: ?*anyopaque,
    vtable: VTable,

    fn connect(self: *WaylandHandle) !void {
        self.listener_ptr = null;
        self.keymap.init();

        self.display = c.wl_display_connect(null) orelse return error.Connect;
        self.registry = c.wl_display_get_registry(self.display) orelse return error.GetRegistry;

        _ = c.wl_registry_add_listener(self.registry, &registry_listener, self);
        _ = c.wl_display_roundtrip(self.display);

        self.surface = c.wl_compositor_create_surface(self.compositor) orelse return error.Surface;
        self.xdg_surface = c.xdg_wm_base_get_xdg_surface(self.xdg_base, self.surface) orelse return error.XdgSurface;

        _ = c.xdg_surface_add_listener(self.xdg_surface, &xdg_surface_listener, self);

        self.xdg_toplevel = c.xdg_surface_get_toplevel(self.xdg_surface) orelse return error.XdgToplevel;
        _ = c.xdg_toplevel_add_listener(self.xdg_toplevel, &xdg_toplevel_listener, self);

        _ = c.wl_seat_add_listener(self.seat, &seat_listener, self);

        self.keyboard = c.wl_seat_get_keyboard(self.seat) orelse return error.Keyboard;
        _ = c.wl_keyboard_add_listener(self.keyboard, &keyboard_listener, self);

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

const seat_listener = c.wl_seat_listener {
    .capabilities = seat_capabilities,
    .name = seat_name,
};

const keyboard_listener = c.wl_keyboard_listener {
    .keymap = keyboard_keymap,
    .enter = keyboard_enter,
    .leave = keyboard_leave,
    .key = keyboard_key,
    .modifiers = keyboard_modifiers,
    .repeat_info = keyboard_repeat_info,
};

fn surface_configure(data: ?*anyopaque, surface: ?*c.xdg_surface, serial: u32) callconv(.c) void {
    const wayland: *WaylandHandle = @ptrCast(@alignCast(data.?));
    c.xdg_surface_ack_configure(surface, serial);
    c.wl_surface_commit(wayland.surface);
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

fn seat_capabilities(data: ?*anyopaque, seat: ?*c.wl_seat, capabilities: u32) callconv(.c) void {
    _ = data;
    _ = seat;
    _ = capabilities;
}

fn seat_name(data: ?*anyopaque, seat: ?*c.wl_seat, name: [*c]const u8) callconv(.c) void {
    _ = data;
    _ = seat;
    _ = name;
}

fn keyboard_keymap(data: ?*anyopaque, keyboard: ?*c.wl_keyboard, format: u32, fd: i32, size: u32) callconv(.c) void {
    const self: *WaylandHandle = @ptrCast(@alignCast(data.?));
    _ = keyboard;

    if (format == 0) @panic("DON'T KNOW HOW TO HANDLE RAW KEY CODES");

    const ptr = std.posix.mmap(null, size, std.posix.PROT.READ, .{ .TYPE = .PRIVATE }, fd, 0) catch unreachable;
    const content: [*c]const u8 = @ptrCast(@alignCast(ptr));

    self.keymap.setKeymap(content);

    //std.debug.print("DATA: {d}, {s}\n", .{fd, ptr});
}

fn keyboard_enter(data: ?*anyopaque, keyboard: ?*c.wl_keyboard, serial: u32, surface: ?*c.wl_surface, keys: [*c]c.wl_array) callconv(.c) void {
    _ = data;
    _ = keyboard;
    _ = surface;
    _ = serial;
    _ = keys;
}

fn keyboard_leave(data: ?*anyopaque, keyboard: ?*c.wl_keyboard, serial: u32, surface: ?*c.wl_surface) callconv(.c) void {
    _ = data;
    _ = keyboard;
    _ = serial;
    _ = surface;
}

fn keyboard_key(data: ?*anyopaque, keyboard: ?*c.wl_keyboard, serial: u32, time: u32, key: u32, state: u32) callconv(.c) void {
    _ = keyboard;
    _ = serial;
    _ = time;
    _ = state; // 0 -> release, 1 -> pressed, 2 -> repeat

    const self: *WaylandHandle = @ptrCast(@alignCast(data.?));
    const sym = self.keymap.getSym(key);
    _ = sym;
    //_ = key;
}

fn keyboard_modifiers(data: ?*anyopaque, keyboard: ?*c.wl_keyboard, serial: u32, depressed: u32, latched: u32, locked: u32, group: u32) callconv(.c) void {
    _ = keyboard;
    _ = serial;

    const self: *WaylandHandle = @ptrCast(@alignCast(data.?));
    self.keymap.setModifiers(depressed, latched, locked, group);
}

fn keyboard_repeat_info(data: ?*anyopaque, keyboard: ?*c.wl_keyboard, rate: i32, delay: i32) callconv(.c) void {
    _ = data;
    _ = keyboard;
    _ = rate;
    _ = delay;
}

fn registry_handle_global(data: ?*anyopaque, registry: ?*c.wl_registry, name: u32, interface: [*c]const u8, version: u32) callconv(.c) void {
    const wayland: *WaylandHandle = @ptrCast(@alignCast(data.?));
    const interface_name: []const u8 = std.mem.span(@as([*:0]const u8, interface));

    if (std.mem.eql(u8, interface_name, std.mem.span(@as([*:0]const u8, c.wl_compositor_interface.name)))) {
        const ptr = c.wl_registry_bind(registry, name, &c.wl_compositor_interface, version);
        wayland.compositor = @ptrCast(@alignCast(ptr.?));
    } else if (std.mem.eql(u8, interface_name, std.mem.span(@as([*:0]const u8, c.xdg_wm_base_interface.name)))) {
        const ptr = c.wl_registry_bind(registry, name, &c.xdg_wm_base_interface, version);
        wayland.xdg_base = @ptrCast(@alignCast(ptr.?));

        _ = c.xdg_wm_base_add_listener(wayland.xdg_base, &xdg_base_listener, wayland);
    } else if (std.mem.eql(u8, interface_name, std.mem.span(@as([*:0]const u8, c.wl_seat_interface.name)))) {
        const ptr = c.wl_registry_bind(registry, name, &c.wl_seat_interface, version);
        wayland.seat = @ptrCast(@alignCast(ptr.?));
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
