const NODE_INDEX: u32 = 1;
const MESH_PATH: []const u8 = "Cube.gltf";
const Index = u16;

pub fn main() !void {
    const width: u32 = 600;
    const height: u32 = 480;

    const application = try Application.init(width, height, std.heap.page_allocator);
    try application.run();
}

pub const Application = struct {
    wayland: Wayland,
    vulkan: Vulkan,
    render: *VulkanRenderGroup,
    sets: [2]*VulkanSet,
    buffers: [2]VulkanBuffer,

    allocator: Allocator,

    fn init(
        width: u32,
        height: u32,
        allocator: std.mem.Allocator,
    ) !*Application {
        const self = try allocator.create(Application);

        try self.allocator.init(50, 100, allocator);
        try self.wayland.init();

        var gltf: GltfParser.Gltf = undefined;
        try gltf.init("Asset/Mesh", MESH_PATH, self.allocator.tmp);

        const display = self.wayland.handle.display;
        const surface = self.wayland.handle.surface;
        try self.vulkan.init(display, surface, width, height, &self.allocator);

        self.buffers[0] = try self.vulkan.addPublicBuffer(Transform, .storage, 1);
        self.sets[0] = try self.vulkan.addDescriptorSet(0);

        try self.buffers[0].append(Transform, &self.vulkan, &.{getTransform(width, height)});
        try self.sets[0].update(&self.vulkan, try self.buffers[0].range(0, null), 0);

        self.buffers[1] = try self.vulkan.addPublicBuffer(View, .uniform, 1);
        self.sets[1] = try self.vulkan.addDescriptorSet(1);

        try self.buffers[1].append(View, &self.vulkan, &.{getView()});
        try self.sets[1].update(&self.vulkan, try self.buffers[1].range(0, null), 0);

        const vertices = try getVertices(gltf, self.allocator.tmp);
        const indices = try getIndices(gltf, self.allocator.tmp);

        self.render = try self.vulkan.addRenderGroup(vertices, indices, &.{ self.sets[0], self.sets[1] });
        self.wayland.setListener(self, .{ .resize = resize });

        return self;
    }

    fn run(self: *Application) !void {
        while (true) {
            self.allocator.tmp_buffer.reset();
            self.wayland.dispatch() catch break;

            try self.vulkan.renderFrame();
        }
    }

    fn resize(ptr: *anyopaque, width: u32, height: u32) void {
        const self: *Application = @ptrCast(@alignCast(ptr));
        const world_transform = getTransform(width, height);

        self.buffers[0].clear();
        self.buffers[0].append(Transform, &self.vulkan, &.{world_transform}) catch @panic("RESIZE BUFFER");

        const range = self.buffers[0].range(0, null) catch @panic("OUT OF BOUNDS");

        self.vulkan.updateDescriptorSet(self.sets[0], range, 0);
        self.vulkan.changeRenderSize(width, height) catch @panic("RESIZE RENDERER");
    }
};

fn getVertices(gltf: GltfParser.Gltf, allocator: std.mem.Allocator) ![]Vertex {
    const mesh = gltf.meshes[0];
    const position = mesh.getPosition(gltf);

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
    const mesh_indices = gltf.meshes[0].getIndices(gltf);
    const indices = try allocator.alloc(u16, mesh_indices.len);

    for (0..mesh_indices.len) |i| {
        indices[i] = mesh_indices[i];
    }

    return indices;
}

fn getTransform(width: u32, height: u32) Transform {
    const w: f32 = @floatFromInt(width);
    const h: f32 = @floatFromInt(height);

    const a: f32 = h / w;
    const matrix = Matrix(4).scale(Vector(4).init(.{ a, 1, 1.0 / 10.0 + 0.1, 1 }));

    return .{
        .transform = matrix,
    };
}

fn getView() View {
    const length = 1.0 / 1.41;
    const quaternion = Quaternion.init(Vector(3).init(.{ length, length, 0 }), std.math.pi / 2.0);
    const matrix = quaternion.matrix();

    // for (0..4) |i| {
    //     for (0..4) |j| {
    //         std.debug.print("{d} ", .{matrix.items[i * 4 + j]});
    //     }
    //     std.debug.print("\n", .{});
    // }

    return .{
        .transform = matrix,
    };
}

pub const Transform = struct {
    transform: Matrix(4),
};

pub const View = struct {
    transform: Matrix(4),
};

const std = @import("std");
const c = @import("Util").c;

const Wayland = @import("Wayland").Wayland;
const Vulkan = @import("Vulkan").Context;
const VulkanRenderGroup = @import("Vulkan").RenderGroup;
const VulkanSet = @import("Vulkan").Descriptor.Set;
const VulkanBuffer = @import("Vulkan").Buffer;
const Vertex = Vulkan.Vertex;

const GltfParser = @import("GltfParser");

const Allocator = @import("Util").Allocator;
const Matrix = @import("Util").Matrix;
const Vector = @import("Util").Vector;
const Quaternion = @import("Util").Quaternion;
