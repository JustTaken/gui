pub const RenderGroup = struct {
    vertices: Buffer,
    indices: Buffer,
    sets: []*Descriptor.Set,

    pub fn init(
        self: *RenderGroup,
        context: *Context,
        vertices: Buffer,
        indices: Buffer,
        sets: []const *Descriptor.Set,
    ) !void {
        self.vertices = vertices;
        self.indices = indices;

        self.sets = try context.allocator.main.alloc(*Descriptor.Set, sets.len);
        @memcpy(self.sets, sets);

        // self.descriptor_sets = try allocator.main.alloc(u32, set_buffers.len);
        // try self.update(library, device, pipeline, manager, set_buffers);
    }

    // fn update(self: *Render, buffers: []Buffer) !void {
    //     _ = self;
    //     for (0..buffers.len) |i| {
    //         _ = i;
    // self.descriptor_sets[i] = try manager.addDescriptorSet(
    //     library,
    //     device,
    //     pipeline.set_layouts[i],
    // );

    // try manager.updateDescriptorSet(
    //     library,
    //     device,
    //     self.descriptor_sets[i],
    //     0,
    //     try set_buffers[i].getRange(0, set_buffers[i].count),
    // );
    // }
    // }
};

const Context = @import("Lib.zig").Context;
const Buffer = @import("Buffer.zig").Buffer;
const Descriptor = @import("Shader.zig").Descriptor;
