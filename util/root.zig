const std = @import("std");

// pub const c = @cImport({
	// @cInclude("vulkan/vulkan.h");
// });

pub const Allocator = struct {
	main: std.mem.Allocator,
	tmp: std.mem.Allocator,

	main_buffer: std.heap.FixedBufferAllocator,
	tmp_buffer: std.heap.FixedBufferAllocator,

	pub fn init(allocator: std.mem.Allocator, main_pages: u32, tmp_pages: u32) !*Allocator {
		const self = try allocator.create(Allocator);
		const page_size = std.heap.pageSize();

		const main_bytes = try allocator.alloc(u8, main_pages * page_size);
		const tmp_bytes = try allocator.alloc(u8, tmp_pages * page_size);

		self.main_buffer = std.heap.FixedBufferAllocator.init(main_bytes);
		self.tmp_buffer = std.heap.FixedBufferAllocator.init(tmp_bytes);

		self.main = self.main_buffer.allocator();
		self.tmp = self.tmp_buffer.allocator();

		return self;
	}

	pub fn clearTmp(self: *Allocator) void {
		self.tmp_buffer.end_index = 0;
	}
};

pub fn List(T: type) type {
	return struct {
		free: std.DoublyLinkedList,
		use: std.DoublyLinkedList,

		const Self = @This();

		pub fn init(self: *Self) void {
			self.free = .{};
			self.use = .{};
		}

		pub fn add(self: *Self) ?*T {
			if (self.free.pop()) |p| {
				self.use.append(p);
				return @fieldParentPtr("node", p);
			}

			return null;
		}

		pub fn create(self: *Self, allocator: std.mem.Allocator) !*T {
			const child = try allocator.create(T);
			self.use.append(&child.node);

			return child;
		}

		pub fn remove(self: *Self, child: ?*T) void {
			if (child) |ch| {
				self.use.remove(&ch.node);
				self.free.prepend(&ch.node);
			}
		}
	};
}

pub fn Vector(N: usize) type {
	return struct {
		items: [N]f32,

		const Self = @This();

		pub fn init(items: [N]f32) Self {
			var self: Self = undefined;

			inline for (0..N) |i| {
				self.items[i] = items[i];
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
			for (0..N * N) |i| {
				result.items[i] = 0;
			}

			inline for (0..N) |i| {
				inline for (0..N) |j| {
					inline for (0..N) |k| {
						result.items[j + i * N] += self.items[j + k * N] * other.items[i * N + k];
					}
				}
			}

			return result;
		}

		pub fn apply(self: Self, vec: Vector(N)) Vector(N) {
			var result: Vector(N) = undefined;
			for (0..N) |i| {
				result.items[i] = 0;
			}

			inline for (0..N) |i| {
				inline for (0..N) |j| {
					result.items[i] += vec.items[j] * self.items[i * N + j];
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
			.x = -self.x * inv,
			.y = -self.y * inv,
			.z = -self.z * inv,
		};
	}

	pub fn mult(self: Quaternion, other: Quaternion) Quaternion {
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
		const other = Quaternion{
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

	pub fn apply_quaternion(self: Quaternion, vec: Vector(3)) Quaternion {
		const other = Quaternion{
			.w = 0,
			.x = vec.items[0],
			.y = vec.items[1],
			.z = vec.items[2],
		};

		const first = self.mult(other);
		const inv = self.inverse();
		return first.mult(inv);
	}

	pub fn matrix(self: Quaternion) Matrix(4) {
		return .{
			.items = .{
				2 * (self.w * self.w + self.x * self.x) - 1,
				2 * (self.x * self.y - self.w * self.z),
				2 * (self.x * self.z + self.w * self.y),
				0,

				2 * (self.x * self.y + self.w * self.z),
				2 * (self.w * self.w + self.y * self.y) - 1,
				2 * (self.y * self.z - self.w * self.x),
				0,

				2 * (self.x * self.z - self.w * self.y),
				2 * (self.y * self.z + self.w * self.x),
				2 * (self.w * self.w + self.z * self.z) - 1,
				0,

				0, 0, 0, 1,
			},
		};
	}
};

pub const Data = struct { indices: []u16, vertices: [][3]f32 };

test "Quaternion Test" {
	const quaternion = Quaternion.init(Vector(3).init(.{ 0, 0, 1 }), std.math.pi / 2.0);
	const result = quaternion.apply(Vector(3).init(.{ 0, 1, 0 }));
	const expect: [3]f32 = .{ -1, 0, 0 };

	const matrix = quaternion.matrix();
	const result_matrix = matrix.apply(Vector(4).init(.{ 0, 1, 0, 0 }));

	for (0..expect.len) |i| {
		const value = std.math.round(result.items[i]);
		const value_matrix = std.math.round(result_matrix.items[i]);

		std.debug.print("|{d}| ", .{value});
		std.debug.print("|{d}|\n", .{value_matrix});

		try std.testing.expectEqual(expect[i], value);
		try std.testing.expectEqual(expect[i], value_matrix);
	}

	std.debug.print("\n", .{});
}
