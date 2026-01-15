pub const Command = struct {
    pub const Buffer = struct {
        handle: c.VkCommandBuffer,
        semaphore: *Semaphores.Child,
    };

    pub const Allocator = struct {
        pools: std.ArrayList(Pool),
        pool_sizes: u32,

        pub fn init(self: *Allocator, context: *Context, sizes: u32) !void {
            self.pools = try std.ArrayList(Pool).initCapacity(context.allocator.main, 10);
            self.pool_sizes = sizes;
        }

        pub fn alloc(self: *Allocator, context: *Context, count: u32) ![]Buffer {
            var index: u32 = 0;

            while (true) {
                defer index += 1;

                if (index >= self.pools.items.len) {
                    const pool = try self.pools.addOne(context.allocator.main);
                    try pool.init(context, self.pool_sizes);

                    return try pool.alloc(context, count);
                } else {
                    return self.pools.items[index].alloc(context, count) catch continue;
                }
            }

            return error.OutOfMemory;
        }
    };

    pub const Pool = struct {
        handle: c.VkCommandPool,
        childs: std.ArrayList(Buffer),

        pub fn init(self: *Pool, context: *Context, size: u32) !void {
            self.childs = try std.ArrayList(Buffer).initCapacity(context.allocator.main, size);

            const pool_info = c.VkCommandPoolCreateInfo{
                .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
                .flags = c.VK_COMMAND_POOL_CREATE_TRANSIENT_BIT | c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
                .queueFamilyIndex = context.device.family_index,
            };

            if (c.VK_SUCCESS != context.lib.device.vkCreateCommandPool(context.device.handle, &pool_info, null, &self.handle)) return error.CommandPool;
        }

        pub fn alloc(self: *Pool, context: *Context, count: u32) ![]Buffer {
            if (self.childs.items.len + count > self.childs.capacity) return error.OutOfMemory;

            const info = c.VkCommandBufferAllocateInfo{
                .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
                .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
                .commandPool = self.handle,
                .commandBufferCount = count,
            };

            const buffer_raws = try context.allocator.tmp.alloc(c.VkCommandBuffer, count);

            if (c.VK_SUCCESS != context.lib.device.vkAllocateCommandBuffers(context.device.handle, &info, buffer_raws.ptr)) return error.AllocateCommandBuffer;

            const buffers = self.childs.addManyAsSliceAssumeCapacity(count);

            for (buffer_raws, 0..) |buffer, i| {
                buffers[i].handle = buffer;
                buffers[i].semaphore = try context.semaphores.add(context);
            }

            return buffers;
        }
    };
};

pub const std = @import("std");
pub const c = @import("Util").c;
pub const Context = @import("Lib.zig").Context;
pub const Semaphores = @import("Sync.zig").Semaphores;
