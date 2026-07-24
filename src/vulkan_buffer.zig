pub const Buffer = struct {
    handle: c.VkBuffer,
    memory: c.VkDeviceMemory,
    capacity: u32,
    len: u32,
    type_size: u32,

    properties: MemoryProperties,

    pub const Range = struct {
        handle: c.VkBuffer,
        offset: u32,
        length: u32,
    };

    pub const Usage = struct {
        usage: std.EnumSet(Kind),

        pub const Kind = enum {
            storage,
            uniform,
            vertex,
            index,

            pub fn into(self: Kind) u32 {
                return switch (self) {
                    .storage => c.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
                    .uniform => c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT,
                    .vertex => c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT,
                    .index => c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT,
                };
            }
        };

        pub fn into(self: Usage) c.VkBufferUsageFlagBits {
            return enum_set_into(Kind, self.usage);
        }

        pub fn init(kinds: []const Kind) Usage {
            return .{
                .usage = std.EnumSet(Kind).initMany(kinds),
            };
        }
    };

    pub const Sharing = enum {
        exclusive,

        pub fn into(self: Sharing) c.VkSharingMode {
            return switch (self) {
                .exclusive => c.VK_SHARING_MODE_EXCLUSIVE,
            };
        }
    };

    pub const MemoryProperties = struct {
        properties: std.EnumSet(Kind),

        pub const Kind = enum {
            host_visible,
            host_coherent,

            pub fn into(self: Kind) u32 {
                return switch (self) {
                    .host_visible => c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT,
                    .host_coherent => c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT,
                };
            }
        };

        pub fn init(properties: []const Kind) MemoryProperties {
            return .{
                .properties = .initMany(properties),
            };
        }

        pub fn into(self: MemoryProperties) c.VkMemoryPropertyFlagBits {
            return enum_set_into(Kind, self.properties);
        }
    };

    pub fn init(T: type, context: *Context, usage: Usage, properties: MemoryProperties, sharing: Sharing, capacity: usize) !Buffer {
        var self: Buffer = undefined;

        self.len = 0;
        self.capacity = @intCast(capacity);
        self.properties = properties;
        self.type_size = @sizeOf(T);

        const total_size = self.capacity * self.type_size;

        const info = c.VkBufferCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .flags = 0,
            .size = total_size,
            .usage = usage.into(),
            .sharingMode = sharing.into(),
        };

        if (c.VK_SUCCESS != context.lib.device.vkCreateBuffer(context.device.handle, &info, null, &self.handle)) return error.CreateBuffer;

        var requirements: c.VkMemoryRequirements = undefined;
        context.lib.device.vkGetBufferMemoryRequirements(context.device.handle, self.handle, &requirements);

        const index = try findMemory(
            context,
            requirements.memoryTypeBits,
            properties,
        );

        const alloc_info = c.VkMemoryAllocateInfo{
            .sType = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .allocationSize = requirements.size,
            .memoryTypeIndex = index,
        };

        if (c.VK_SUCCESS != context.lib.device.vkAllocateMemory(context.device.handle, &alloc_info, null, &self.memory)) return error.AllocateMemory;
        if (c.VK_SUCCESS != context.lib.device.vkBindBufferMemory(context.device.handle, self.handle, self.memory, 0)) return error.BindBuffer;

        return self;
    }

    pub fn range(self: *Buffer, offset: u32, count: ?u32) !Range {
        const length = count orelse self.capacity - offset;

        if (offset + length > self.capacity) return error.OutOfBounds;

        const size = self.type_size;

        return Range{
            .handle = self.handle,
            .offset = size * offset,
            .length = size * length,
        };
    }

    pub fn append(
        self: *Buffer,
        T: type,
        context: *Context,
        data: []const T,
    ) !void {
        if (self.type_size != @sizeOf(T)) return error.MissmatchTypeSize;
        if (!(self.properties.properties.contains(.host_coherent) and self.properties.properties.contains(.host_visible))) return error.NotVisibleToHost; // TODO: copy from staging buffer
        if (self.len + data.len > self.capacity) return error.OutOfMemory;

        const remap = try self.map(T, context, self.len, @intCast(data.len));
        @memcpy(remap, data);

        self.len += @intCast(data.len);

        self.unmap(context);
    }

    pub fn map(
        self: *Buffer,
        T: type,
        context: *Context,
        offset: u32,
        count: u32,
    ) ![]T {
        var data: []T = undefined;

        if (c.VK_SUCCESS != context.lib.device.vkMapMemory(context.device.handle, self.memory, offset * @sizeOf(T), count * @sizeOf(T), 0, @ptrCast(&data.ptr))) return error.MapMemory;

        data.len = count;

        return data;
    }

    pub fn unmap(self: *Buffer, context: *Context) void {
        context.lib.device.vkUnmapMemory(context.device.handle, self.memory);
    }

    fn findMemory(context: *Context, type_filter: u32, memory_properties: MemoryProperties) !u32 {
        const properties = memory_properties.into();

        for (0..context.device.memory_properties.memoryTypeCount) |i| {
            const index: u5 = @intCast(i);
            const base: u32 = 1;

            if (type_filter & (base << index) > 0) {
                if (context.device.memory_properties.memoryTypes[i].propertyFlags & properties == properties) {
                    return index;
                }
            }
        }

        return error.MemoryTypeIndex;
    }

    pub fn clear(self: *Buffer) void {
        self.len = 0;
    }
};

fn enum_set_into(T: type, set: std.EnumSet(T)) u32 {
    var iterator = set.iterator();
    var flag: u32 = 0;

    while (iterator.next()) |key| {
        flag |= key.into();
    }

    return flag;
}

const std = @import("std");
const c = @import("Util").c;

const Context = @import("Lib.zig").Context;
