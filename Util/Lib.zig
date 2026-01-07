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

pub fn Vector(N: usize) type {
    return struct {
        items: [N]f32,

        const Self = @This();

        pub fn init(items: [N]f32) Self {
            var self: Self = undefined;

            inline for (0..N) |i| {
                self.items[i]  = items[i];
            }

            return self;
        }
    };
}

pub fn Matrix(N: usize) type {
    return struct {
        items: [N * N]f32,

        const Self = @This();

        pub fn scale(vec: Vector(N)) Self {
            var self: Self = undefined;

            inline for (0..N) |i| {
                self.items[N * i + i] = vec.items[i];
            }

            return self;
        }

        pub fn translate(vec: Vector(N)) Self {
            var self: Self = undefined;
            inline for (0..N) |i| {
                self.items[N * (i + 1) - 1] = vec.items[i];
            }

            return self;
        }

        pub fn mult(self: Self, other: Self) Self {
            var result: Self = undefined;

            inline for (0..N) |i| {
                inline for (0..N) |j| {
                    for (0..N) |k| {
                        result.items[j + i * N] += self.items[j + k * N] * other.items[i * N + k];
                    }
                }
            }

            return result;
        }
    };
}

pub const Quaternion = struct {
    w: f32,
    x: f32,
    y: f32,
    z: f32,

    pub fn init(vector: Vector(3), angle: f32) Quaternion {
        const a = angle / 2.0;
        const cos = @cos(a);
        const sin = @sin(a);

        return .{
            .w = cos,
            .x = vector.items[0] * sin,
            .y = vector.items[1] * sin,
            .z = vector.items[2] * sin,
        };
    }

    pub fn inverse(self: Quaternion) Quaternion {
        const length = self.w * self.w + self.x * self.x + self.y * self.y + self.z * self.z;
        const inv = 1.0 / length;

        return .{
            .w = self.w * inv,
            .x = - self.x * inv,
            .y = - self.y * inv,
            .z = - self.z * inv,
        };
    }

    pub fn mult(self: Quaternion, other: Quaternion) Quaternion {
        // a = w
        // b = x
        // c = y
        // d = z

        const w = self.w * other.w - self.x * other.x - self.y * other.y - self.z * other.z;
        const x = self.w * other.x + self.x * other.w + self.y * other.z - self.z * other.y;
        const y = self.w * other.y - self.x * other.z + self.y * other.w + self.z * other.x;
        const z = self.w * other.z + self.x * other.y - self.y * other.x + self.z * other.w;

        return .{
            .w = w,
            .x = x,
            .y = y,
            .z = z,
        };
    }

    pub fn apply(self: Quaternion, vec: Vector(3)) Vector(3) {
        const other = Quaternion {
            .w = 0,
            .x = vec.items[0],
            .y = vec.items[1],
            .z = vec.items[2],
        };

        const first = self.mult(other);
        const inv = self.inverse();
        const result = first.mult(inv);

        return Vector(3).init(.{ result.x, result.y, result.z });
    }

    pub fn matrix(self: Quaternion) Matrix {
        return .{
              self.w * self.w - self.x * self.x - self.y * self.y - self.z * self.z,
            - self.w * self.x - self.x * self.w - self.y * self.z + self.z * self.y,
            - self.w * self.y + self.x * self.z - self.y * self.w - self.z * self.x,
            - self.w * self.z - self.x * self.y + self.y * self.x - self.z * self.x,

              self.x * self.w + self.w * self.x + self.z * self.y - self.y * self.z,
            - self.x * self.x + self.w * self.w + self.z * self.z + self.y * self.y,
            - self.x * self.y - self.w * self.z + self.z * self.w - self.y * self.x,
            - self.x * self.z + self.w * self.y - self.z * self.x - self.y * self.w,

              self.y * self.w - self.z * self.x + self.w * self.y + self.x * self.z,
            - self.y * self.x - self.z * self.w + self.w * self.z - self.x * self.y,
            - self.y * self.y + self.z * self.z + self.w * self.w + self.x * self.x,
            - self.y * self.z - self.z * self.y - self.w * self.x + self.x * self.w,

              self.z * self.w + self.y * self.x - self.x * self.y + self.w * self.z,
            - self.z * self.x + self.y * self.w - self.x * self.z - self.w * self.y,
            - self.z * self.y - self.y * self.z - self.x * self.w + self.w * self.x,
            - self.z * self.z + self.y * self.y + self.x * self.x + self.w * self.w,
        };
    }
};
