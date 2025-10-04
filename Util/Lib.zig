const std = @import("std");

pub const c = @cImport({
    @cDefine("VK_USE_PLATFORM_WAYLAND_KHR", "1");
    @cInclude("Include.h");
});

pub const Allocator = struct {
    main: std.mem.Allocator,
    tmp: std.mem.Allocator,

    main_buffer: std.heap.FixedBufferAllocator,
    tmp_buffer: std.heap.FixedBufferAllocator,

    pub fn init(self: *Allocator, main_pages: u32, tmp_pages: u32, allocator: std.mem.Allocator) !void {
        const main_bytes = try allocator.alloc(u8, main_pages * 4096);
        const tmp_bytes = try allocator.alloc(u8, tmp_pages * 4096);

        self.main_buffer = std.heap.FixedBufferAllocator.init(main_bytes);
        self.tmp_buffer = std.heap.FixedBufferAllocator.init(tmp_bytes);

        self.main = self.main_buffer.allocator();
        self.tmp = self.tmp_buffer.allocator();
    }

    pub fn deinit(self: *Allocator) void {
        std.heap.page_allocator.free(self.tmp_buffer.buffer);
        std.heap.page_allocator.free(self.main_buffer.buffer);
    }
};

pub const Matrix = [16]f32;

pub const Math = struct {
    pub fn scale(vec: [3]f32) Matrix {
        return .{
            vec[0], 0,      0,      0,
            0,      vec[1], 0,      0,
            0,      0,      vec[2], 0,
            0,      0,      0,      1,
        };
    }

    pub fn translate(vec: [3]f32) Matrix {
        return .{
            1, 0, 0, vec[0],
            0, 1, 0, vec[1],
            0, 0, 1, vec[2],
            0, 0, 0, 1,
        };
    }

    pub fn multiply(first: Matrix, second: Matrix) Matrix {
        var matrix: Matrix = .{
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
        };

        for (0..4) |i| {
            for (0..4) |j| {
                for (0..4) |k| {
                    matrix[j + i * 4] += first[j + k * 4] * second[i * 4 + k];
                }
            }
        }

        return matrix;
    }
};
