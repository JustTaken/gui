pub const Char = u8;
pub const String = []const Char;
pub const Object = struct {
    name: String,
    value: Value,
};

pub const Array = []Value;
pub const Map = std.StringHashMap(Value);

const ValueKind = enum {
    string,
    array,
    map,
    int,
    float,
};

pub const Value = union(ValueKind) {
    string: String,
    array: Array,
    map: Map,
    int: i32,
    float: f32,
};

pub const Error = error{
    Assertion,
    FileNotFound,
    ReadFile,
    OutOfMemory,
    ParsingFloat,
    ParsingInt,
};

const Context = struct {
    content: String,
    objects: std.ArrayList(Object),
    index: u32,
    allocator: std.mem.Allocator,
    line: u32,
    nest_map: u32,

    fn init(content: String, allocator: std.mem.Allocator) Error!Context {
        const objects = try std.ArrayList(Object).initCapacity(allocator, 10);

        return .{
            .content = content,
            .index = 0,
            .line = 1,
            .objects = objects,
            .allocator = allocator,
            .nest_map = 0,
        };
    }

    fn parseString(self: *Context) Error!String {
        try self.assert('"');

        const start = self.index;
        while (self.peek(0)) |c| {
            if (!isAlpha(c)) break;
            self.advance();
        }

        const end = self.index;
        try self.assert('"');

        return self.content[start..end];
    }

    fn parseObject(self: *Context) Error!Object {
        const name = try self.parseString();

        try self.assert(':');

        const value = try self.parseValue();

        return .{
            .name = name,
            .value = value,
        };
    }

    fn parseMap(self: *Context) Error!Map {
        self.nest_map += 1;
        try self.assert('{');

        var map = Map.init(self.allocator);

        while (true) {
            const object = self.parseObject() catch break;
            try map.put(object.name, object.value);

            if (!self.match(',')) {
                break;
            }
        }

        try self.assert('}');
        self.nest_map -= 1;

        return map;
    }

    fn parseArray(self: *Context) Error!Array {
        try self.assert('[');

        var array = std.ArrayList(Value).empty;

        while (true) {
            const value = self.parseValue() catch break;

            try array.append(self.allocator, value);
            if (!self.match(',')) break;
        }

        try self.assert(']');

        return array.items;
    }

    fn parseNumber(self: *Context) Error!Value {
        var is_float = false;
        const start = self.index;

        while (self.peek(0)) |c| {
            if (!isNumber(c)) {
                if (c != '.') break else is_float = true;
            }

            self.advance();
        }

        const end = self.index;
        const content = self.content[start..end];

        if (is_float) {
            return .{
                .float = std.fmt.parseFloat(f32, content) catch return error.ParsingFloat,
            };
        } else {
            return .{
                .int = std.fmt.parseInt(i32, content, 10) catch return error.ParsingInt,
            };
        }
    }

    fn parseValue(self: *Context) Error!Value {
        self.skipWhitespace();

        const n = self.peek(0) orelse return error.Assertion;

        const value: Value = switch (n) {
            '{' => .{
                .map = try self.parseMap(),
            },
            '"' => .{
                .string = try self.parseString(),
            },
            '[' => .{
                .array = try self.parseArray(),
            },
            else => try self.parseNumber(),
        };

        return value;
    }

    fn next(self: *Context) ?Char {
        defer self.advance();
        return self.peek(0);
    }

    fn advance(self: *Context) void {
        if (self.content[self.index] == '\n') {
            self.line += 1;
        }

        self.index += 1;
    }

    fn peek(self: *Context, offset: u32) ?Char {
        if (self.index + offset >= self.content.len) return null;

        return self.content[self.index + offset];
    }

    fn skipWhitespace(self: *Context) void {
        while (self.peek(0)) |c| {
            if (!std.ascii.isWhitespace(c)) break;
            self.advance();
        }
    }

    fn match(self: *Context, char: Char) bool {
        self.skipWhitespace();

        const c = self.peek(0) orelse return false;

        if (c != char) return false;

        self.advance();
        return true;
    }

    fn assert(self: *Context, char: Char) Error!void {
        self.skipWhitespace();

        if (!self.match(char)) {
            return error.Assertion;
        }
    }
};

fn isNumber(c: Char) bool {
    return (c >= '0' and c <= '9') or c == '-';
}

fn isAlpha(c: Char) bool {
    return c != '"' and std.ascii.isAscii(c); //(c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or isNumber(c);
}

pub fn parse(path: []const u8, allocator: std.mem.Allocator) Error!Map {
    var file = std.fs.cwd().openFile(path, .{}) catch return error.FileNotFound;
    defer file.close();

    const content = file.readToEndAlloc(allocator, 4096 * 100) catch return error.ReadFile;
    var context = try Context.init(content, allocator);

    return try context.parseMap();
}

const std = @import("std");
