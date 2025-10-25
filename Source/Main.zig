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
const GltfParser = @import("GltfParser");

const c = @import("Util").c;
const Allocator = @import("Util").Allocator;
const Math = @import("Util").Math;
const Matrix = @import("Util").Matrix;

const NODE_INDEX: u32 = 0;
const MESH_PATH: []const u8 = "Geometry.gltf";

pub fn main() !void {
    // const matrix_one = Math.IDENTITY;
    // const matrix_two = Math.scale(.{ 1, 1, 1 });
    // const matrix_three = Math.scale(.{ 3, 3, 3 });

    // const first = Math.scale(.{ 3, 3, 3 });
    // const second = Math.translate(.{ 2, 2, 2 });
    // const result = Math.multiply(first, second);

    // std.debug.print("{any} * {any}\n{any}\n", .{ first, second, result });
    // var allocator: Allocator = undefined;
    // try allocator.init(100, 90, std.heap.page_allocator);

    // var gltf: GltfParser.Gltf = undefined;
    // try gltf.init("Asset/Mesh/Cube.gltf", allocator.main);

    // std.debug.print("ASSET: {any}\n", .{gltf.asset});
    // std.debug.print("SCENES: {any}\n", .{gltf.scenes});
    // std.debug.print("NODES: {any}\n", .{gltf.nodes});
    // std.debug.print("MESHES: {any}\n", .{gltf.meshes});
    // std.debug.print("ACCESSORS: {any}\n", .{gltf.accessors});
    // std.debug.print("ANIMATIONS: {any}\n", .{gltf.animations});
    // std.debug.print("SKINS: {any}\n", .{gltf.skins});
    // std.debug.print("BUFFER_VIEWS: {any}\n", .{gltf.buffer_views});

    // const data = gltf.getCompleteMesh(0);
    // _ = data;

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

        try self.allocator.init(10, 100, allocator);
        try self.wayland.init();
        try self.library.init();
        try self.instance.init(&self.library, &self.allocator);
        try self.surface.init(&self.library, self.instance, self.wayland.handle.display, self.wayland.handle.surface);
        try self.device.init(&self.library, self.instance, self.surface, &self.allocator);
        try self.manager.init(&self.library, self.device, &self.allocator);
        try self.swapchain.startup(&self.library, self.device, &self.allocator);
        try self.swapchain.new(&self.library, self.device, width, height);
        try self.pipeline.init(&self.library, self.device, self.swapchain.format.format, Vertex, &self.allocator);

        var gltf: GltfParser.Gltf = undefined;
        try gltf.init("Asset/Mesh", MESH_PATH, self.allocator.tmp);

        const vertices = try getVertices(gltf, self.allocator.tmp);
        const indices = try getIndices(gltf, self.allocator.tmp);

        self.vertices = try VulkanBuffer(Vertex).init(
            &self.library,
            self.device,
            c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
            c.VK_SHARING_MODE_EXCLUSIVE,
            .{ .data = vertices },
        );

        self.indices = try VulkanBuffer(u16).init(
            &self.library,
            self.device,
            c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
            c.VK_SHARING_MODE_EXCLUSIVE,
            .{ .data = indices },
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

fn getVertices(gltf: GltfParser.Gltf, allocator: std.mem.Allocator) ![]Vertex {
    const mesh = gltf.complete_nodes[NODE_INDEX].mesh.?;
    const position = mesh.position;

    const vertices = try allocator.alloc(Vertex, position.len);

    for (0..position.len) |i| {
        vertices[i] = .{
            .position = .{ position[i][0], position[i][1], position[i][2] },
            .color = .{1, 0, 0},
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

pub const Vertex = struct {
    position: [3]f32,
    color: [3]f32,
}

//const VERTICES = [_]Vertex{
//    .{ .position = .{   0.5, - 0.5 }, .color = .{ 1.0, 0.0, 0.0 } },
//    .{ .position = .{   0.5,   0.5 }, .color = .{ 0.0, 1.0, 0.0 } },
//    .{ .position = .{ - 0.5,   0.5 }, .color = .{ 0.0, 0.0, 1.0 } },
//};
//
//const INDICES = [_]u16{
//    0, 1, 2,
//};;
