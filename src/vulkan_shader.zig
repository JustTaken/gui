pub const Module = struct {
    handle: c.VkShaderModule,

    pub fn init(context: *Context, path: []const u8) !Module {
        var self: Module = undefined;

        const base_dir = try std.fs.selfExeDirPathAlloc(context.allocator.tmp);
        const file_path = try std.fs.path.join(context.allocator.tmp, &.{ base_dir, "../", path });
        const file = try std.fs.openFileAbsolute(file_path, .{});
        const size = try file.getEndPos();
        const buffer = try context.allocator.tmp.alloc(u32, (size + 3) / @sizeOf(u32));

        const bytes: [*]u8 = @ptrCast(@alignCast(buffer.ptr));
        const len = try file.readAll(bytes[0..size]);

        if (len != size) return error.ReadFile;

        const info = c.VkShaderModuleCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
            .codeSize = @intCast(size),
            .pCode = buffer.ptr,
        };

        if (c.VK_SUCCESS != context.lib.device.vkCreateShaderModule(context.device.handle, &info, null, &self.handle)) return error.ShaderModule;

        return self;
    }

    pub fn deinit(self: *const Module, context: *Context) void {
        context.lib.device.vkDestroyShaderModule(context.device.handle, self.handle, null);
    }
};

pub const Input = struct {
    singles: []Layout,

    pub const Attribute = struct {
        format: c.VkFormat,
        offset: u32,
        location: u32,
    };

    pub const Build = struct {
        bindings: []c.VkVertexInputBindingDescription,
        attributes: []c.VkVertexInputAttributeDescription,
    };

    pub const Layout = struct {
        size: u32,
        attributes: []Attribute,

        pub fn init(T: type, context: *Context) !Layout {
            const FIELDS = @typeInfo(T).@"struct".fields;
            const count = FIELDS.len;

            var self = Layout{
                .size = @sizeOf(T),
                .attributes = try context.allocator.tmp.alloc(Attribute, count),
            };

            var offset: u32 = 0;
            inline for (FIELDS, 0..) |field, i| {
                self.attributes[i] = .{
                    .format = getFormat(field.type),
                    .offset = offset,
                    .location = i,
                };

                offset += @sizeOf(field.type);
            }

            return self;
        }

        fn getSize(T: type) u32 {
            switch (@typeInfo(T)) {
                .float => |f| {
                    std.debug.assert(f.bits == 32);
                    return 4;
                },
                else => @panic("NOT SUPPORTED"),
            }
        }

        fn getFormat(T: type) c.VkFormat {
            switch (@typeInfo(T)) {
                .array => |a| {
                    const size = getSize(a.child);
                    _ = size;

                    switch (a.len) {
                        1 => return c.VK_FORMAT_R32_SFLOAT,
                        2 => return c.VK_FORMAT_R32G32_SFLOAT,
                        3 => return c.VK_FORMAT_R32G32B32_SFLOAT,
                        4 => return c.VK_FORMAT_R32G32B32A32_SFLOAT,
                        else => @panic("NOT SUPPORTED"),
                    }
                },
                else => @panic("NOT SUPPORTED"),
            }

            @panic("NOT SUPPORTED");
        }
    };

    pub fn init(singles: []const Layout, allocator: std.mem.Allocator) !Input {
        var self: Input = undefined;

        self.singles = try allocator.alloc(Layout, singles.len);
        @memcpy(self.singles, singles);

        return self;
    }

    pub fn build(self: Input, allocator: std.mem.Allocator) !Build {
        var bindings = try std.ArrayList(c.VkVertexInputBindingDescription).initCapacity(allocator, self.singles.len);
        var attributes = try std.ArrayList(c.VkVertexInputAttributeDescription).initCapacity(allocator, 10);

        for (self.singles, 0..) |single, i| {
            try bindings.append(allocator, .{
                .binding = @intCast(i),
                .stride = single.size,
                .inputRate = c.VK_VERTEX_INPUT_RATE_VERTEX,
            });

            for (single.attributes) |att| {
                try attributes.append(allocator, .{
                    .binding = @intCast(i),
                    .location = att.location,
                    .format = att.format,
                    .offset = att.offset,
                });
            }
        }

        return .{
            .bindings = bindings.items,
            .attributes = attributes.items,
        };
    }
};

pub const Descriptor = struct {
    pub const Allocator = struct {
        pools: std.ArrayList(Pool),
        sizes: []Size,
        max: u32,

        pub fn init(self: *Allocator, context: *Context, sizes: []const Size, max: u32) !void {
            self.pools = try std.ArrayList(Pool).initCapacity(context.allocator.main, 10);
            self.max = max;
            self.sizes = try context.allocator.main.alloc(Size, sizes.len);

            @memcpy(self.sizes, sizes);
        }

        pub fn alloc(self: *Allocator, context: *Context, layouts: []Descriptor.Set.Layout) ![]Set {
            var index: u32 = 0;

            while (true) {
                defer index += 1;

                if (index >= self.pools.items.len) {
                    const pool = try self.pools.addOne(context.allocator.main);
                    try pool.init(context, self.sizes, self.max);

                    return try pool.alloc(context, layouts);
                } else {
                    return self.pools.items[index].alloc(context, layouts) catch continue;
                }
            }

            return error.OutOfMemory;
        }
    };

    pub const Size = struct {
        kind: Kind,
        count: u32,

        pub const Kind = enum {
            storage,
            uniform,

            pub fn into(self: Kind) u32 {
                return switch (self) {
                    .storage => c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
                    .uniform => c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                };
            }
        };

        pub fn init(kind: Kind, count: u32) Size {
            return .{
                .count = count,
                .kind = kind,
            };
        }
    };

    pub const Pool = struct {
        handle: c.VkDescriptorPool,
        childs: std.ArrayList(Set),

        pub fn init(self: *Pool, context: *Context, sizes: []Size, max: u32) !void {
            const pool_sizes = try context.allocator.tmp.alloc(c.VkDescriptorPoolSize, sizes.len);
            self.childs = try std.ArrayList(Set).initCapacity(context.allocator.main, max);

            for (sizes, 0..) |size, i| {
                pool_sizes[i] = .{
                    .type = size.kind.into(),
                    .descriptorCount = size.count,
                };
            }

            const descriptor_pool_info = c.VkDescriptorPoolCreateInfo{
                .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
                .poolSizeCount = @intCast(pool_sizes.len),
                .pPoolSizes = pool_sizes.ptr,
                .maxSets = max,
            };

            if (c.VK_SUCCESS != context.lib.device.vkCreateDescriptorPool(context.device.handle, &descriptor_pool_info, null, &self.handle)) return error.DescriptorPool;
        }

        pub fn alloc(self: *Pool, context: *Context, layouts: []Descriptor.Set.Layout) ![]Set {
            const count: u32 = @intCast(layouts.len);

            if (self.childs.items.len + count > self.childs.capacity) return error.OutOfDescriptors;

            const raw_layouts = try context.allocator.tmp.alloc(c.VkDescriptorSetLayout, count);
            for (0..count) |i| {
                raw_layouts[i] = layouts[i].handle;
            }

            const allocate_info = c.VkDescriptorSetAllocateInfo{
                .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
                .descriptorPool = self.handle,
                .descriptorSetCount = count,
                .pSetLayouts = raw_layouts.ptr,
            };

            const handles = try context.allocator.tmp.alloc(c.VkDescriptorSet, count);
            if (c.VK_SUCCESS != context.lib.device.vkAllocateDescriptorSets(context.device.handle, &allocate_info, handles.ptr)) return error.OutOfDescriptors;

            const sets = self.childs.addManyAsSliceAssumeCapacity(count);
            for (0..count) |i| {
                sets[i] = .{
                    .handle = handles[i],
                    .layout = layouts[i],
                };
            }

            return sets;
        }
    };

    pub const UpdateInfo = struct {
        set: *Set,
        range: ?Buffer.Range,
        binding: u32,
    };

    pub const Set = struct {
        handle: c.VkDescriptorSet,
        layout: Layout,

        pub const Layouts = struct {
            childs: []Layout,

            pub const Build = struct {
                handles: []c.VkDescriptorSetLayout,
            };

            pub fn init(context: *Context, childs: []const Layout) !Layouts {
                var self: Layouts = undefined;

                self.childs = try context.allocator.main.alloc(Layout, childs.len);
                @memcpy(self.childs, childs);

                return self;
            }

            pub fn build(self: Layouts, context: *Context) !Build {
                var result: Build = undefined;
                result.handles = try context.allocator.tmp.alloc(c.VkDescriptorSetLayout, self.childs.len);

                for (self.childs, 0..) |child, i| {
                    result.handles[i] = child.handle;
                }

                return result;
            }
        };

        pub const Layout = struct {
            handle: c.VkDescriptorSetLayout,
            bindings: []Binding,

            pub const Binding = struct {
                kind: Kind,
                stage: Stage,
                count: u32,

                pub const Kind = enum {
                    storage,
                    uniform,

                    fn into(self: Kind) u32 {
                        return switch (self) {
                            .storage => c.VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
                            .uniform => c.VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                        };
                    }
                };

                pub const Stage = enum {
                    vertex,
                    fragment,

                    fn into(self: Stage) u32 {
                        return switch (self) {
                            .vertex => c.VK_SHADER_STAGE_VERTEX_BIT,
                            .fragment => c.VK_SHADER_STAGE_FRAGMENT_BIT,
                        };
                    }
                };

                pub fn init(kind: Kind, stage: Stage, count: u32) Binding {
                    return .{
                        .kind = kind,
                        .stage = stage,
                        .count = count,
                    };
                }
            };

            pub fn init(context: *Context, binds: []const Binding) !Layout {
                var self: Layout = undefined;

                self.bindings = try context.allocator.main.alloc(Binding, binds.len);
                @memcpy(self.bindings, binds);

                const bindings = try context.allocator.tmp.alloc(c.VkDescriptorSetLayoutBinding, self.bindings.len);

                for (self.bindings, 0..) |binding, i| {
                    bindings[i] = .{
                        .binding = @intCast(i),
                        .descriptorType = binding.kind.into(),
                        .stageFlags = binding.stage.into(),
                        .descriptorCount = binding.count,
                    };
                }

                const info = c.VkDescriptorSetLayoutCreateInfo{
                    .sType = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
                    .bindingCount = @intCast(bindings.len),
                    .pBindings = bindings.ptr,
                };

                if (c.VK_SUCCESS != context.lib.device.vkCreateDescriptorSetLayout(context.device.handle, &info, null, &self.handle)) return error.DescriptorSetLayout;

                return self;
            }
        };

        pub fn update(self: *Set, context: *Context, range: ?Buffer.Range, binding: u32) !void {
            if (range) |r| {
                const buffer_info = c.VkDescriptorBufferInfo{
                    .buffer = r.handle,
                    .range = r.length,
                    .offset = r.offset,
                };

                const write_set = c.VkWriteDescriptorSet{
                    .sType = c.VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
                    .dstSet = self.handle,
                    .dstBinding = binding,
                    .descriptorCount = 1,
                    .descriptorType = self.layout.bindings[binding].kind.into(),
                    .pBufferInfo = &buffer_info,
                };

                context.lib.device.vkUpdateDescriptorSets(context.device.handle, 1, &write_set, 0, null);
            }
        }
    };
};

const std = @import("std");
const c = @import("Util").c;
const Context = @import("Lib.zig").Context;
const Buffer = @import("Buffer.zig").Buffer;
const Command = @import("Command.zig").Command;
