const std = @import("std");

const Wayland = @import("Wayland").Wayland;
const VulkanLibrary = @import("Vulkan").Library;
const VulkanInstance = @import("Vulkan").Instance;
const VulkanDevice = @import("Vulkan").Device;
const VulkanSurface = @import("Vulkan").Surface;
const VulkanSwapchain = @import("Vulkan").Swapchain;
const VulkanPipeline = @import("Vulkan").Pipeline;
const VulkanManager = @import("Vulkan").Manager;
const VulkanBuffer = @import("Vulkan").Buffer;

const c = @import("Util").c;
const Allocator = @import("Util").Allocator;

pub fn main() !void {
    const width: u32 = 600;
    const height: u32 = 480;

    const application = try Application.init(width, height, std.heap.page_allocator);
    try application.run();
}

pub const Application = struct {
    library: VulkanLibrary,
    wayland: Wayland,
    instance: VulkanInstance,
    surface: VulkanSurface,
    device: VulkanDevice,
    manager: VulkanManager,
    swapchain: VulkanSwapchain,
    pipeline: VulkanPipeline,
    vertices: VulkanBuffer(Vertex),
    indices: VulkanBuffer(u16),

    allocator: Allocator,

    fn init(width: u32, height: u32, allocator: std.mem.Allocator) !*Application {
        const self = try allocator.create(Application);

        try self.allocator.init(10, 90, allocator);
        try self.wayland.init();
        try self.library.init();
        try self.instance.init(&self.library, &self.allocator);
        try self.surface.init(&self.library, self.instance, self.wayland.handle.display, self.wayland.handle.surface);
        try self.device.init(&self.library, self.instance, self.surface, &self.allocator);
        try self.manager.init(&self.library, self.device, &self.allocator);
        try self.swapchain.startup(&self.library, self.device, &self.allocator);
        try self.swapchain.new(&self.library, self.device, width, height);
        try self.pipeline.init(&self.library, self.device, self.swapchain.format.format, Vertex, &self.allocator);

        self.vertices = try VulkanBuffer(Vertex).init(
            &self.library,
            self.device,
            c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
            c.VK_SHARING_MODE_EXCLUSIVE,
            .{ .data = &VERTICES },
        );

        self.indices = try VulkanBuffer(u16).init(
            &self.library,
            self.device,
            c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
            c.VK_SHARING_MODE_EXCLUSIVE,
            .{ .data = &INDICES },
        );

        self.wayland.setListener(self, .{ .resize = resize });

        return self;
    }

    fn run(self: *Application) !void {
        while (true) {
            self.allocator.tmp_buffer.reset();
            self.wayland.dispatch() catch break;

            const image = try self.swapchain.nextImage(
                &self.library,
                self.device,
                &self.manager,
            );

            try self.swapchain.renderToImage(
                &self.library,
                self.device,
                self.pipeline,
                &self.manager,
                image,
                Vertex,
                self.vertices,
                self.indices,
            );
        }
    }

    fn resize(ptr: *anyopaque, width: u32, height: u32) void {
        const self: *Application = @ptrCast(@alignCast(ptr));

        self.swapchain.new(
            &self.library,
            self.device,
            width,
            height,
        ) catch unreachable;
    }
};

const VERTICES = [_]Vertex{
    .{ .position = .{ 0.5, -0.5 }, .color = .{ 1.0, 0.0, 0.0 } },
    .{ .position = .{ 0.5, 0.5 }, .color = .{ 0.0, 1.0, 0.0 } },
    .{ .position = .{ -0.5, 0.5 }, .color = .{ 0.0, 0.0, 1.0 } },
};

const INDICES = [_]u16{
    0, 1, 2,
};

pub const Vertex = struct {
    position: [2]f32,
    color: [3]f32,
};
