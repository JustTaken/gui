
const NODE_INDEX: u32 = 0;
const MESH_PATH: []const u8 = "Geometry.gltf";
const Index = u16;

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
    descriptor_buffers: [2]VulkanBuffer,
    render_groups: []VulkanRenderGroup,

    allocator: Allocator,

    fn init(
        width: u32,
        height: u32,
        allocator: std.mem.Allocator,
    ) !*Application {
        const self = try allocator.create(Application);

        try self.allocator.init(10, 100, allocator);
        try self.wayland.init();
        try self.library.init();
        try self.instance.init(&self.library, &self.allocator);

        try self
            .surface
            .init(
                &self.library,
                self.instance,
                self.wayland.handle.display,
                self.wayland.handle.surface
            );

        try self
            .device
            .init(
                &self.library,
                self.instance,
                self.surface,
                &self.allocator
            );

        try self.manager.init(&self.library, self.device, &self.allocator);
        try self.swapchain.startup(&self.library, self.device, &self.allocator);
        try self.swapchain.new(&self.library, self.device, width, height);

        try self
            .pipeline
            .init(
                &self.library,
                self.device,
                self.swapchain.format.format,
                Vertex,
                &.{
                    &.{.{
                        .binding = 0,
                        .descriptorType = c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
                        .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
                        .descriptorCount = 1,
                    }},
                    &.{.{
                        .binding = 0,
                        .descriptorType = c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                        .stageFlags = c.VK_SHADER_STAGE_VERTEX_BIT,
                        .descriptorCount = 1,
                    }},
                },
                &self.allocator
            );

        var gltf: GltfParser.Gltf = undefined;
        try gltf.init("Asset/Mesh", MESH_PATH, self.allocator.tmp);

        self.descriptor_buffers[0] = try VulkanBuffer.init(
            Transform,
            &self.library,
            self.device,
            c.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
            c.VK_SHARING_MODE_EXCLUSIVE,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT
                | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            1,
        );

        self.descriptor_buffers[1] = try VulkanBuffer.init(
            View,
            &self.library,
            self.device,
            c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
            c.VK_SHARING_MODE_EXCLUSIVE,
            c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT
                | c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
            1,
        );

        const position = getTransform(@floatFromInt(width), @floatFromInt(height));
        const view = getView();

        try self.descriptor_buffers[0].update(
            Transform,
            &self.library,
            self.device,
            0,
            &.{position},
        );

        try self.descriptor_buffers[1].update(
            View,
            &self.library,
            self.device,
            0,
            &.{view},
        );

        const vertices = try getVertices(gltf, self.allocator.tmp);
        const indices = try getIndices(gltf, self.allocator.tmp);

        self.render_groups = try self
            .allocator
            .main
            .alloc(VulkanRenderGroup, 1);

        try self.render_groups[0].init(
            Vertex,
            u16,
            &self.library,
            self.device,
            self.pipeline,
            &self.manager,
            vertices,
            indices,
            &self.descriptor_buffers,
            &self.allocator,
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
                self.render_groups,
                &self.allocator,
            );
        }
    }

    fn resize(ptr: *anyopaque, width: u32, height: u32) void {
        const self: *Application = @ptrCast(@alignCast(ptr));
        const world_transform = getTransform(@floatFromInt(width), @floatFromInt(height));

        self.descriptor_buffers[0].update(
            Transform,
            &self.library,
            self.device,
            0,
            &.{world_transform},
        ) catch unreachable;

        self.swapchain.new(
            &self.library,
            self.device,
            width,
            height,
        ) catch unreachable;
    }
};

fn getVertices(gltf: GltfParser.Gltf, allocator: std.mem.Allocator) ![]Vertex {
    const mesh = gltf.complete_nodes[NODE_INDEX].mesh.?;
    const position = mesh.position;

    const vertices = try allocator.alloc(Vertex, position.len);

    for (0..position.len) |i| {
        vertices[i] = .{
            .position = .{ position[i][0], position[i][1], position[i][2] },
            .color = .{ 1, 1, 1 },
        };
    }

    return vertices;
}

fn getIndices(gltf: GltfParser.Gltf, allocator: std.mem.Allocator) ![]u16 {
    const mesh = gltf.complete_nodes[NODE_INDEX].mesh.?;
    const indices = try allocator.alloc(u16, mesh.indices.len);

    for (0..mesh.indices.len) |i| {
        indices[i] = mesh.indices[i];
    }

    return indices;
}

fn getTransform(width: f32, height: f32) Transform {
    const a: f32 = height / width;

    return .{
        .transform = Matrix(4).scale(Vector(4).init(.{ a, 1, 1, 1 })),
    };
}

fn getView() View {
    return .{
        .transform = Matrix(4).scale(Vector(4).init(.{ 1, 1, 1, 1 })),
    };
}

pub const Vertex = struct {
    position: [3]f32,
    color: [3]f32,
};

pub const Transform = struct {
    transform: Matrix(4),

};

pub const View = struct {
    transform: Matrix(4),
};

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
const VulkanRenderGroup = @import("Vulkan").RenderGroup;
const GltfParser = @import("GltfParser");

const c = @import("Util").c;
const Allocator = @import("Util").Allocator;
const Matrix = @import("Util").Matrix;
const Vector = @import("Util").Vector;

