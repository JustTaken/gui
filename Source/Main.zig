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

    fn init(width: u32, height: u32, allocator: std.mem.Allocator) !*Application {
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

        try self.buffers[0].append(Transform, &self.vulkan, &.{.{ .transform = Matrix(4).scale(Vector(4).init(.{ 1.0, 1.0, 1.0, 1 })) }});
        try self.sets[0].update(&self.vulkan, try self.buffers[0].range(0, null), 0);

        self.buffers[1] = try self.vulkan.addPublicBuffer(World, .uniform, 1);
        self.sets[1] = try self.vulkan.addDescriptorSet(1);

        try self.buffers[1].append(World, &self.vulkan, &.{getWorld(width, height)});
        try self.sets[1].update(&self.vulkan, try self.buffers[1].range(0, null), 0);

        const data = try getVertices(gltf, &self.allocator);

        self.render = try self.vulkan.addRenderGroup(data.vertices, data.indices, &.{ self.sets[0], self.sets[1] });
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
        const world_transform = getWorld(width, height);

        self.buffers[1].clear();
        self.buffers[1].append(World, &self.vulkan, &.{world_transform}) catch @panic("RESIZE BUFFER");

        const range = self.buffers[1].range(0, null) catch @panic("OUT OF BOUNDS");

        self.vulkan.updateDescriptorSet(self.sets[1], range, 0);
        self.vulkan.changeRenderSize(width, height) catch @panic("RESIZE RENDERER");
    }
};

const MeshData = struct {
    vertices: []Vertex,
    indices: []u16,
};

fn getVertices(gltf: GltfParser.Gltf, allocator: *Allocator) !MeshData {
    const mesh = gltf.meshes[0];
    const position_data = try mesh.getPrimitiveData(gltf, .position, allocator.tmp);
    const index_data = try mesh.getIndices(gltf, allocator.tmp);
    const material_data = try mesh.getMaterials(gltf, allocator.tmp);

    var vertex = try std.ArrayList(Vertex).initCapacity(allocator.tmp, 100);
    var index = try std.ArrayList(u16).initCapacity(allocator.tmp, 100);

    var position_elements: usize = 0;
    for (0..mesh.primitives.len) |i| {
        const color: [4]f32 = material_data[i].?.pbr_metallic_roughness.base_color_factor;
        const positions = position_data[i].?.into([3]f32);
        const indices = index_data[i].into(u16);

        for (0..positions.len) |j| {
            try vertex.append(allocator.tmp, .{
                .position = .{ positions[j][0], positions[j][1], positions[j][2] },
                .color = .{ color[0], color[1], color[2] },
            });
        }

        for (0..indices.len) |j| {
            try index.append(allocator.tmp, @intCast(indices[j] + position_elements));
        }

        position_elements += positions.len;
    }

    return .{
        .vertices = vertex.items,
        .indices = index.items,
    };
}

fn getWorld(width: u32, height: u32) World {
    const quaternion = Quaternion.init(Vector(3).init(.{ 1, 0, 0 }), -std.math.pi / 1.0);

    const w: f32 = @floatFromInt(width);
    const h: f32 = @floatFromInt(height);

    const a: f32 = h / w;

    return .{
        .view = quaternion.matrix(),
        .projection = Matrix(4).scale(Vector(4).init(.{ a, -1.0, 1.0 / 10.0 + 0.1, 1 })),
    };
}

pub const Transform = struct {
    transform: Matrix(4),
};

pub const World = struct {
    view: Matrix(4),
    projection: Matrix(4),
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
