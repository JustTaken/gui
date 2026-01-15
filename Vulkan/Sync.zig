pub const Fences = struct {
    childs: List(Child),

    pub const Child = struct {
        handle: c.VkFence,
        node: std.DoublyLinkedList.Node,

        pub fn init(self: *Child, context: *Context) !void {
            const info = c.VkFenceCreateInfo{
                .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
                .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
            };

            if (c.VK_SUCCESS != context.lib.device.vkCreateFence(context.device.handle, &info, null, &self.handle)) return error.Fence;
        }
    };

    pub fn init(self: *Fences) void {
        self.childs.init();
    }

    pub fn add(self: *Fences, context: *Context) !*Child {
        if (self.childs.add()) |ch| {
            return ch;
        } else {
            const child = try self.childs.create(context.allocator.main);
            try child.init(context);
            return child;
        }
    }
};

pub const Semaphores = struct {
    childs: List(Child),

    pub const Child = struct {
        handle: c.VkSemaphore,
        node: std.DoublyLinkedList.Node,

        pub fn init(self: *Child, context: *Context) !void {
            const info = c.VkSemaphoreCreateInfo{
                .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
            };

            if (c.VK_SUCCESS != context.lib.device.vkCreateSemaphore(context.device.handle, &info, null, &self.handle)) return error.Semaphore;
        }
    };

    pub fn init(self: *Semaphores) void {
        self.childs.init();
    }

    pub fn add(self: *Semaphores, context: *Context) !*Child {
        if (self.childs.add()) |ch| {
            return ch;
        } else {
            const child = try self.childs.create(context.allocator.main);
            try child.init(context);
            return child;
        }
    }
};

const std = @import("std");
const c = @import("Util").c;
const Context = @import("Lib.zig").Context;
const List = @import("Util").List;
