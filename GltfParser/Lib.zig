const Index = u16;

pub const Gltf = struct {
    map: JsonParser.Map,
    asset: Asset,
    scenes: []Scene,
    nodes: []Node,
    meshes: []Mesh,
    accessors: []Accessor,
    skins: []Skin,
    animations: []Animation,
    buffer_views: []BufferView,
    buffers: []Buffer,

    complete_nodes: []CompleteNode,

    const Asset = struct {
        generator: JsonParser.String,
        version: JsonParser.String,

        fn init(self: *Asset, map: JsonParser.Map) !void {
            const asset = map.get("asset") orelse return error.MissingAsset;

            self.generator = asset.map.get("generator").?.string;
            self.version = asset.map.get("version").?.string;
        }
    };

    const Scene = struct {
        name: JsonParser.String,
        nodes: []Index,

        fn init(self: *Scene, map: JsonParser.Map, allocator: std.mem.Allocator) !void {
            self.name = map.get("name").?.string;

            const nodes = map.get("nodes").?.array;

            self.nodes = try allocator.alloc(Index, nodes.len);

            for (0..nodes.len) |i| {
                self.nodes[i] = @intCast(nodes[i].int);
            }
        }

        fn initArray(array: JsonParser.Array, allocator: std.mem.Allocator) ![]Scene {
            const scenes = try allocator.alloc(Scene, array.len);

            for (0..array.len) |i| {
                try scenes[i].init(array[i].map, allocator);
            }

            return scenes;
        }
    };

    const Node = struct {
        name: JsonParser.String,
        mesh: ?Index,
        skin: ?Index,
        children: []Index,
        transform: Matrix(4),

        fn init(self: *Node, map: JsonParser.Map, allocator: std.mem.Allocator) !void {
            self.name = map.get("name").?.string;
            self.mesh = if (map.get("mesh")) |i| @intCast(i.int) else null;
            self.skin = if (map.get("skin")) |s| @intCast(s.int) else null;
            self.transform = Matrix(4).scale(Vector(4).init(.{ 1, 1, 1, 1 }));

            if (map.get("translation")) |t| self.transform = self.transform.mult(intoTranslationMatrix(t.array));
            if (map.get("scale")) |s| self.transform = self.transform.mult(intoScaleMatrix(s.array));

            if (map.get("children")) |c| {
                const array = c.array;
                self.children = try allocator.alloc(Index, array.len);

                for (0..array.len) |i| {
                    self.children[i] = @intCast(array[i].int);
                }
            } else self.children = &.{};
        }

        fn initArray(array: JsonParser.Array, allocator: std.mem.Allocator) ![]Node {
            const nodes = try allocator.alloc(Node, array.len);

            for (0..array.len) |i| {
                try nodes[i].init(array[i].map, allocator);
            }

            return nodes;
        }
    };

    const Mesh = struct {
        name: JsonParser.String,
        primitives: []Primitive,

        const Primitive = struct {
            attributes: AttributeMap,
            indices: Index,

            fn init(self: *Primitive, map: JsonParser.Map) !void {
                const attributes = map.get("attributes").?.map;

                self.attributes = AttributeMap.init(.{});

                self.indices = @intCast(map.get("indices").?.int);
                if (attributes.get("POSITION")) |position| self.attributes.put(.position, @intCast(position.int));
                if (attributes.get("NORMAL")) |normal| self.attributes.put(.normal, @intCast(normal.int));
                if (attributes.get("TEXCOORD_0")) |texcoord| self.attributes.put(.texcoord, @intCast(texcoord.int));
                if (attributes.get("JOINTS_0")) |joints| self.attributes.put(.joint, @intCast(joints.int));
                if (attributes.get("WEIGHTS")) |weights| self.attributes.put(.weight, @intCast(weights.int));
            }

            fn initArray(array: JsonParser.Array, allocator: std.mem.Allocator) ![]Primitive {
                const primitives = try allocator.alloc(Primitive, array.len);

                for (0..array.len) |i| {
                    try primitives[i].init(array[i].map);
                }

                return primitives;
            }
        };

        const AttributeMap = std.EnumMap(AttributeKind, Index);

        const AttributeKind = enum {
            position,
            normal,
            texcoord,
            joint,
            weight,
        };

        fn init(self: *Mesh, map: JsonParser.Map, allocator: std.mem.Allocator) !void {
            self.name = map.get("name").?.string;
            self.primitives = try Primitive.initArray(map.get("primitives").?.array, allocator);
        }

        fn initArray(array: JsonParser.Array, allocator: std.mem.Allocator) ![]Mesh {
            const meshes = try allocator.alloc(Mesh, array.len);

            for (0..array.len) |i| {
                try meshes[i].init(array[i].map, allocator);
            }

            return meshes;
        }
    };

    const Accessor = struct {
        buffer_view: u32,
        byte_offset: u32,
        count: u32,
        component_type: ComponentType,
        kind: Kind,
        min: []u8,
        max: []u8,

        const ComponentType = enum(u16) {
            float32 = 5126,
            int8 = 5120,
            int16 = 5122,
            uint8 = 5121,
            uint16 = 5123,
            uint32 = 5125,

            fn init(int: i32) ComponentType {
                return std.enums.fromInt(ComponentType, int).?;
            }

            fn size(self: ComponentType) u32 {
                return switch (self) {
                    .float32 => 32,
                    .int8 => 8,
                    .int16 => 16,
                    .uint8 => 8,
                    .uint16 => 16,
                    .uint32 => 32,
                };
            }
        };

        const Kind = enum {
            VEC2,
            VEC3,
            VEC4,
            MAT2,
            MAT3,
            MAT4,
            SCALAR,

            fn init(string: JsonParser.String) Kind {
                return compareEnum(Kind, string);
            }

            fn len(self: Kind) u32 {
                return switch (self) {
                    .SCALAR => 1,
                    .VEC2 => 2,
                    .VEC3 => 3,
                    .VEC4 => 4,
                    .MAT2 => 4,
                    .MAT3 => 9,
                    .MAT4 => 16,
                };
            }
        };

        fn init(self: *Accessor, map: JsonParser.Map) !void {
            self.buffer_view = @intCast(map.get("bufferView").?.int);
            self.component_type = ComponentType.init(map.get("componentType").?.int);
            self.kind = Kind.init(map.get("type").?.string);
            self.count = @intCast(map.get("count").?.int);
            self.byte_offset = if (map.get("byteOffset")) |offset| @intCast(offset.int) else 0;

            if (map.get("sparse")) |_| return error.Assertion;
        }

        fn initArray(array: JsonParser.Array, allocator: std.mem.Allocator) ![]Accessor {
            const accessors = try allocator.alloc(Accessor, array.len);

            for (0..array.len) |i| {
                try accessors[i].init(array[i].map);
            }

            return accessors;
        }
    };

    const BufferView = struct {
        buffer: u32,
        byte_length: u32,
        byte_offset: u32,
        // target: Index,

        fn init(self: *BufferView, map: JsonParser.Map) !void {
            self.buffer = @intCast(map.get("buffer").?.int);
            self.byte_length = @intCast(map.get("byteLength").?.int);
            self.byte_offset = @intCast(map.get("byteOffset").?.int);

            if (map.get("byteStride")) |_| return error.Assertion;

            // self.target = @intCast(map.get("target").?.int);
        }

        fn initArray(array: JsonParser.Array, allocator: std.mem.Allocator) ![]BufferView {
            const buffer_views = try allocator.alloc(BufferView, array.len);

            for (0..array.len) |i| {
                try buffer_views[i].init(array[i].map);
            }

            return buffer_views;
        }
    };

    const Buffer = struct {
        content: []u8,

        fn init(self: *Buffer, map: JsonParser.Map, dir: std.fs.Dir, allocator: std.mem.Allocator) !void {
            const uri = map.get("uri").?.string;
            const size = map.get("byteLength").?.int;

            self.content = try allocator.alloc(u8, @intCast(size));
            _ = try dir.readFile(uri, self.content);
        }

        fn initArray(array: JsonParser.Array, dir: std.fs.Dir, allocator: std.mem.Allocator) ![]Buffer {
            const buffers = try allocator.alloc(Buffer, array.len);

            for (0..array.len) |i| {
                try buffers[i].init(array[i].map, dir, allocator);
            }

            return buffers;
        }
    };

    const Skin = struct {
        name: JsonParser.String,
        inverseBindMatrices: Index,
        joints: []Index,

        fn init(self: *Skin, map: JsonParser.Map, allocator: std.mem.Allocator) !void {
            self.name = map.get("name").?.string;
            self.inverseBindMatrices = @intCast(map.get("inverseBindMatrices").?.int);

            const joints = map.get("joints").?.array;

            self.joints = try allocator.alloc(Index, joints.len);

            for (0..joints.len) |i| {
                self.joints[i] = @intCast(joints[i].int);
            }
        }

        fn initArray(array_opt: ?JsonParser.Value, allocator: std.mem.Allocator) ![]Skin {
            const array = if (array_opt) |a| a.array else return &.{};

            const skins = try allocator.alloc(Skin, array.len);

            for (0..array.len) |i| {
                try skins[i].init(array[i].map, allocator);
            }

            return skins;
        }
    };

    const Animation = struct {
        name: JsonParser.String,
        channels: []Channel,
        samplers: []Sampler,

        const Channel = struct {
            sampler: Index,
            target: Target,

            const Target = struct {
                node: Index,
                path: Path,

                const Path = enum {
                    translation,
                    rotation,
                    scale,

                    fn init(string: JsonParser.String) Path {
                        return compareEnum(Path, string);
                    }
                };

                fn init(self: *Target, map: JsonParser.Map) void {
                    self.node = @intCast(map.get("node").?.int);
                    self.path = Path.init(map.get("path").?.string);
                }
            };

            fn init(self: *Channel, map: JsonParser.Map) void {
                self.sampler = @intCast(map.get("sampler").?.int);
                self.target.init(map.get("target").?.map);
            }

            fn initArray(array: JsonParser.Array, allocator: std.mem.Allocator) ![]Channel {
                const channels = try allocator.alloc(Channel, array.len);

                for (0..array.len) |i| {
                    channels[i].init(array[i].map);
                }

                return channels;
            }
        };

        const Sampler = struct {
            input: Index,
            output: Index,
            interpolation: Interpolation,

            const Interpolation = enum {
                LINEAR,
                STEP,

                fn init(string: JsonParser.String) Interpolation {
                    return compareEnum(Interpolation, string);
                }
            };

            fn init(self: *Sampler, map: JsonParser.Map) void {
                self.input = @intCast(map.get("input").?.int);
                self.output = @intCast(map.get("output").?.int);
                self.interpolation = Interpolation.init(map.get("interpolation").?.string);
            }

            fn initArray(array: JsonParser.Array, allocator: std.mem.Allocator) ![]Sampler {
                const samplers = try allocator.alloc(Sampler, array.len);

                for (0..array.len) |i| {
                    samplers[i].init(array[i].map);
                }

                return samplers;
            }
        };

        fn init(self: *Animation, map: JsonParser.Map, allocator: std.mem.Allocator) !void {
            self.name = map.get("name").?.string;

            self.channels = try Channel.initArray(map.get("channels").?.array, allocator);
            self.samplers = try Sampler.initArray(map.get("samplers").?.array, allocator);
        }

        fn initArray(array_opt: ?JsonParser.Value, allocator: std.mem.Allocator) ![]Animation {
            const array = if (array_opt) |a| a.array else return &.{};
            const animations = try allocator.alloc(Animation, array.len);

            for (0..array.len) |i| {
                try animations[i].init(array[i].map, allocator);
            }

            return animations;
        }
    };

    const CompleteMesh = struct {
        indices: []Index,
        position: [][3]f32,
        normal: [][3]f32,
        texcoord: [][2]f32,
        joints: [][4]u8,
        weights: [][4]f32,
    };

    const CompleteSkin = struct {
        inverseBindingMatrices: Matrix(4),
        joints: []Index,
    };

    const CompleteNode = struct {
        children: []*CompleteNode,
        mesh: ?CompleteMesh,
        skin: ?CompleteSkin,
        transform: Matrix(4),
    };

    fn getCompleteNodes(self: *Gltf, allocator: std.mem.Allocator) ![]CompleteNode {
        const complete_nodes = try allocator.alloc(CompleteNode, self.nodes.len);

        for (0..self.nodes.len) |i| {
            complete_nodes[i] = try self.getCompleteNode(self.nodes[i], complete_nodes, allocator);
        }

        const root_node_indices = try self.findRootNodes(allocator);

        for (root_node_indices) |i| {
            self.completeNodeTransform(&complete_nodes[i], complete_nodes, null);
        }

        return complete_nodes;
    }

    fn findRootNodes(self: *Gltf, allocator: std.mem.Allocator) ![]Index {
        const root_nodes_flag = try allocator.alloc(bool, self.nodes.len);
        @memset(root_nodes_flag, true);

        for (0..self.nodes.len) |j| {
            const node = self.nodes[j];

            for (0..node.children.len) |i| {
                root_nodes_flag[node.children[i]] = false;
            }
        }

        const root_nodes = try allocator.alloc(Index, self.nodes.len);
        var count: u32 = 0;

        for (0..self.nodes.len) |i| {
            if (root_nodes_flag[i]) {
                root_nodes[count] = @intCast(i);
                count += 1;
            }
        }

        return root_nodes[0..count];
    }

    fn completeNodeTransform(self: *Gltf, node: *CompleteNode, complete_nodes: []CompleteNode, parent_transform: ?Matrix(4)) void {
        const parent = parent_transform orelse Matrix(4).scale(Vector(4).init(.{ 1, 1, 1, 1 }));
        node.transform = parent.mult(node.transform);

        for (0..node.children.len) |i| {
            self.completeNodeTransform(node.children[i], complete_nodes, node.transform);
        }
    }

    fn getCompleteNode(self: *Gltf, node: Node, nodes: []CompleteNode, allocator: std.mem.Allocator) !CompleteNode {
        var complete_node = CompleteNode {
            .children = &.{},
            .mesh = null,
            .skin = null,
            .transform = Matrix(4).scale(Vector(4).init(.{ 1, 1, 1, 1 })),
        };

        complete_node.transform = node.transform;
        complete_node.children = try allocator.alloc(*CompleteNode, node.children.len);

        for (0..node.children.len) |i| {
            complete_node.children[i] = &nodes[node.children[i]];
        }

        if (node.mesh) |mesh| {
            complete_node.mesh = self.getCompleteMesh(mesh);
        }

        if (node.skin) |skin| {
            complete_node.skin = self.getCompleteSkin(skin);
        }

        return complete_node;
    }

    fn getCompleteSkin(self: *Gltf, index: Index) CompleteSkin {
        const skin = self.skins[index];

        var complete_skin: CompleteSkin = undefined;

        complete_skin.inverseBindingMatrices = self.getView(skin.inverseBindMatrices, Matrix(4))[0];
        complete_skin.joints = skin.joints;

        return complete_skin;
    }

    fn getCompleteMesh(self: *Gltf, index: Index) CompleteMesh {
        const mesh = self.meshes[index];
        const primitives = mesh.primitives[0];
        const attributes = primitives.attributes;

        var data = CompleteMesh {
            .indices = &.{},
            .position = &.{},
            .normal = &.{},
            .texcoord = &.{},
            .joints = &.{},
            .weights = &.{},
        };

        //std.debug.print("PRIMITIVE INDICES: {any}\n", .{primitives.indices});

        data.indices = self.getView(primitives.indices, Index);
        data.position = self.getView(attributes.get(.position).?, [3]f32);
        data.normal = self.getView(attributes.get(.normal).?, [3]f32);
        data.texcoord = self.getView(attributes.get(.texcoord).?, [2]f32);

        //std.debug.print("MESH: {d}\n", .{index});
        //std.debug.print("INDICES: {any}\n", .{data.indices});
        //std.debug.print("POSITION: {any}\n", .{data.position});
        //std.debug.print("NORMAL: {any}\n", .{data.normal});
        //std.debug.print("TEXCOORD: {any}\n", .{data.texcoord});

        if (attributes.get(.joint)) |joint| {
            data.joints = self.getView(joint, [4]u8);
            //std.debug.print("JOINTS: {any}\n", .{data.joints});
        }

        if (attributes.get(.weight)) |weight| {
            data.weights = self.getView(weight, [4]f32);
            //std.debug.print("WEIGHTS: {any}\n", .{data.weights});
        }

        return data;
    }

    fn getView(self: *Gltf, accessor_index: Index, T: type) []T {
        const accessor = self.accessors[accessor_index];
        const buffer_view = self.buffer_views[accessor.buffer_view];

        compareType(T, accessor);

        const size: u32 = @sizeOf(T) * accessor.count;

        std.debug.assert(size == buffer_view.byte_length);

        const buffer = self.buffers[buffer_view.buffer];
        const start = buffer_view.byte_offset + accessor.byte_offset;

        const end = size + start;
        const view: []T = @ptrCast(@alignCast(buffer.content[start..end]));

        std.debug.assert(view.len == accessor.count);

        return view;
    }

    pub fn init(self: *Gltf, dir_path: []const u8, path: []const u8, allocator: std.mem.Allocator) !void {
        var dir = try std.fs.cwd().openDir(dir_path, .{});
        defer dir.close();

        var file = try dir.openFile(path, .{});
        defer file.close();

        self.map = try JsonParser.parse(file, allocator);

        try self.asset.init(self.map);

        self.scenes = try Scene.initArray(self.map.get("scenes").?.array, allocator);
        self.nodes = try Node.initArray(self.map.get("nodes").?.array, allocator);
        self.meshes = try Mesh.initArray(self.map.get("meshes").?.array, allocator);
        self.accessors = try Accessor.initArray(self.map.get("accessors").?.array, allocator);
        self.skins = try Skin.initArray(self.map.get("skins"), allocator);
        self.animations = try Animation.initArray(self.map.get("animations"), allocator);
        self.buffer_views = try BufferView.initArray(self.map.get("bufferViews").?.array, allocator);
        self.buffers = try Buffer.initArray(self.map.get("buffers").?.array, dir, allocator);

       // for (0..self.buffer_views.len) |i| {
       //     const start = self.buffer_views[i].byte_offset;
       //     const length = self.buffer_views[i].byte_length;
       //     const buffer = self.buffers[self.buffer_views[i].buffer];

       //     //std.debug.print("CONTENT: {d} -> {any}\n", .{i, buffer.content[start..start + length]});
       // }

        self.complete_nodes = try self.getCompleteNodes(allocator);
    }
};

fn intoTranslationMatrix(array: JsonParser.Array) Matrix(4) {
    var vec = Vector(4).init(.{ 0, 0, 0, 1 });

    for (0..array.len) |i| {
        switch (array[i]) {
            .float => |float| vec.items[i] = float,
            .int => |int| vec.items[i] = @floatFromInt(int),
            else => @panic("TODO"),
        }
    }

    return Matrix(4).translate(vec);
}

fn intoScaleMatrix(array: JsonParser.Array) Matrix(4) {
    var vec = Vector(4).init(.{ 0, 0, 0, 1 });

    for (0..array.len) |i| {
        switch (array[i]) {
            .float => |float| vec.items[i] = float,
            .int => |int| vec.items[i] = @floatFromInt(int),
            else => @panic("TODO"),
        }
    }

    return Matrix(4).scale(vec);
}

fn compareType(T: type, accessor: Gltf.Accessor) void {
    switch (@typeInfo(T)) {
        .array => |a| {
            std.debug.assert(a.len == accessor.kind.len());
            std.debug.assert(@sizeOf(a.child) * 8 == accessor.component_type.size());
        },
        .int => |i| {
            std.debug.assert(i.bits == accessor.component_type.size());
        },
        else => @panic("TODO"),
    }
}

fn compareEnum(K: type, string: JsonParser.String) K {
    const FIELDS = @typeInfo(K).@"enum".fields;

    inline for (FIELDS) |field| {
        if (std.mem.eql(JsonParser.Char, field.name, string)) return @enumFromInt(field.value);
    }

    @panic("TODO");
}

const JsonParser = @import("JsonParser");
const Matrix = @import("Util").Matrix;
const Vector = @import("Util").Vector;
const std = @import("std");
