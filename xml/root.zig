const std = @import("std");

pub const Parser = struct {
	allocator: std.mem.Allocator,
	nodes: std.ArrayList(Node),
	content: []const u8,
	index: usize,

	pub fn parse(allocator: std.mem.Allocator, path: []const u8) !Parser {
		const content = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);

		var self: Parser = undefined;

		self.allocator = allocator;
		self.nodes = std.ArrayList(Node) {};
		self.content = content;
		self.index = 0;

		while (try Node.init(&self)) |node| {
			self.nodes.append(self.allocator, node) catch return error.OutOfMemory;
		}

		return self;
	}

	pub const Node = struct {
		name: []const u8,
		properties: std.ArrayList(Property),
		childs: std.ArrayList(Node),
		comment: []const u8,

		const Property = struct {
			name: []const u8,
			value: []const u8,

			fn init(parser: *Parser) !?Property {
				parser.skipWhitespace();

				if (parser.peek(0)) |c| {
					if (c == '>' or c == '/' or c == '?') return null;
				}

				var self: Property = undefined;
				self.name = Property.parseName(parser);
				self.value = try Property.parseValue(parser);

				return self;
			}

			fn parseValue(parser: *Parser) ![]const u8 {
				try parser.assert('=');
				return parser.parseString();
			}

			fn parseName(parser: *Parser) []const u8 {
				const start = parser.index;

				while (parser.peek(0)) |c| {
					if (c == '=') break;
					parser.advance(1);
				}

				const end = parser.index;

				return parser.content[start..end];
			}
		};

		fn parseName(parser: *Parser) []const u8 {
			parser.skipWhitespace();

			const start = parser.index;

			while (parser.peek(0)) |c| {
				if (std.ascii.isWhitespace(c) or c == '>' or c == '/') break;
				parser.advance(1);
			}

			const end = parser.index;

			return parser.content[start..end];
		}

		fn parseProperties(parser: *Parser) !std.ArrayList(Property) {
			var properties = std.ArrayList(Property){};

			while (try Property.init(parser)) |property| {
				properties.append(parser.allocator, property) catch return error.OutOfMemory;
			}

			return properties;
		}

		fn parseComment(parser: *Parser) ![]const u8 {
			const start = parser.index;

			while (parser.peek(0)) |c| {
				if (c == '<') break;
				parser.advance(1);
			}

			const end = parser.index;

			return parser.content[start..end];
		}

		fn parseChilds(parser: *Parser) !std.ArrayList(Node) {
			var childs = std.ArrayList(Node) {};

			while (try Node.init(parser)) |node| {
				childs.append(parser.allocator, node) catch return error.OutOfMemory;
			}

			return childs;
		}

		fn skipComment(parser: *Parser) !void {
			try parser.assert('<');
			try parser.assert('!');
			try parser.assert('-');
			try parser.assert('-');

			while (parser.peek(2)) |c| {
				if (c == '>') {
					if (parser.matchPeek('-', 0) and parser.matchPeek('-', 1)) {
						parser.advance(3);
						parser.skipWhitespace();
						return;
					}
				}

				parser.advance(1);
			}

			return error.Assertion;
		}

		fn init(parser: *Parser) error{OutOfMemory, Assertion, NameMatch}!?Node {
			parser.skipWhitespace();

			if (parser.atEnd(0)) return null;

			if (parser.matchPeek('>', 0)) return null;
			if (parser.matchPeek('>', 1)) return null;
			if (parser.matchPeek('/', 1)) return null;
			if (parser.matchPeek('!', 1)) try Node.skipComment(parser);

			try parser.assert('<');

			var self: Node = undefined;

			self.name = Node.parseName(parser);
			self.properties = try Node.parseProperties(parser);

			if (!parser.match('>')) {
				if (parser.match('/') or parser.match('?')) {
				} else return error.Assertion;

				try parser.assert('>');

				return self;
			}

			self.comment = try Node.parseComment(parser);
			self.childs = try Node.parseChilds(parser);

			try parser.assert('<');
			try parser.assert('/');

			const end_name = Node.parseName(parser);

			if (!std.mem.eql(u8, end_name, self.name)) {
				std.debug.print("Expected {s}, found: {s}\n", .{self.name, end_name});
				return error.NameMatch;
			}

			try parser.assert('>');

			return self;
		}
	};

	fn parseString(self: *Parser) ![]const u8 {
		self.skipWhitespace();

		try self.assert('"');
		const start = self.index;

		while (self.peek(0)) |c| {
			if (c == '"') break;
			self.advance(1);
		}

		const end = self.index;

		try self.assert('"');

		return self.content[start..end];
	}

	inline fn assert(self: *Parser, char: u8) !void {
		if (!self.match(char)) return error.Assertion;
	}

	inline fn match(self: *Parser, char: u8) bool {
		if (self.matchPeek(char, 0)) {
			self.advance(1);
			return true;
		}

		return false;
	}

	inline fn matchPeek(self: *Parser, char: u8, offset: usize) bool {
		const c = self.peek(offset) orelse return false;

		return c == char;
	}

	inline fn peek(self: *Parser, offset: usize) ?u8 {
		if (!self.atEnd(offset)) {
			return self.content[self.index + offset];
		}

		return null;
	}

	inline fn atEnd(self: *Parser, offset: usize) bool {
		return self.index + offset >= self.content.len;
	}

	inline fn advance(self: *Parser, offset: usize) void {
		self.index += offset;
	}

	inline fn skipWhitespace(self: *Parser) void {
		while (self.peek(0)) |c| {
			if (!std.ascii.isWhitespace(c)) break;
			self.advance(1);
		}
	}
};
