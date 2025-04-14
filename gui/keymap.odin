package main

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:unicode"

Identifier :: distinct []u8
String :: distinct []u8
Number :: u32
Indicator :: Number
Keycode :: distinct Identifier
Alias :: distinct Identifier

Key :: union {
	Identifier,
	Indicator,
	Keycode,
	Alias,
}

Pair :: struct {
	key:   Key,
	value: Token,
}

Keyword :: enum {
	Indicator,
	Alias,
	Keymap,
	Keycodes,
	Types,
	Compatibility,
	Symbols,
}

Symbol :: enum {
	Greater,
	Less,
	SquareOpen,
	SquareClose,
	Semicolon,
	BraceOpen,
	BraceClose,
	ParenOpen,
	ParenClose,
	Plus,
	Minus,
	Comma,
	Equal,
	Dot,
	Bang,
}

Token :: union {
	Symbol,
	Identifier,
	Number,
	String,
	Keyword,
}

Tokenizer :: struct {
	line:   u32,
	offset: u32,
	bytes:  []u8,
	token:  Token,
	codes:  [dynamic]KeyCode,
	pairs:  [dynamic]Pair,
	tokens: [dynamic]Token,
}

KeyCode :: struct {
	key:    Identifier,
	values: []Token,
}

main :: proc() {
	ok: bool
	bytes: []u8
	keymap: []KeyCode
	err: Error

	bytes, ok = os.read_entire_file("output.txt")
	keymap, err = keymap_from_bytes(bytes, context.allocator)

	if err != nil {
		fmt.println("Error", err)
	}
}

keymap_from_bytes :: proc(
	bytes: []u8,
	allocator: runtime.Allocator,
) -> (
	keymap: []KeyCode,
	err: Error,
) {
	tokenizer := Tokenizer {
		bytes  = bytes,
		offset = 0,
		line   = 0,
	}

	parse_keymap(&tokenizer, allocator) or_return

	for code in tokenizer.codes[:] {
		for value in code.values {
			#partial switch t in value {
			case Identifier:
				fmt.print("", string(value.(Identifier)))
			case Number:
				fmt.print("", value.(Number))
			case:
				fmt.println(value)
				panic("SHOULD NOT HAPPEN")
			}
		}

		fmt.println(" ->", string(code.key))
	}

	return keymap, nil
}

@(private = "file")
parse_keymap :: proc(tokenizer: ^Tokenizer, allocator: runtime.Allocator) -> Error {
	advance(tokenizer) or_return
	assert_type(tokenizer, Keyword) or_return
	assert_keyword(tokenizer, .Keymap) or_return
	advance(tokenizer) or_return
	assert_type(tokenizer, Symbol) or_return
	assert_symbol(tokenizer, .BraceOpen) or_return

	parse_keycodes(tokenizer, allocator) or_return
	parse_types(tokenizer) or_return
	parse_compatibility(tokenizer) or_return
	parse_symbols(tokenizer, allocator) or_return

	return nil
}

@(private = "file")
parse_keycodes :: proc(tokenizer: ^Tokenizer, allocator: runtime.Allocator) -> Error {
	advance(tokenizer) or_return
	assert_type(tokenizer, Keyword) or_return
	assert_keyword(tokenizer, .Keycodes)

	advance(tokenizer) or_return
	assert_type(tokenizer, String) or_return

	advance(tokenizer) or_return
	assert_type(tokenizer, Symbol) or_return
	assert_symbol(tokenizer, .BraceOpen) or_return

	tokenizer.pairs = make([dynamic]Pair, 0, 1000, allocator)

	outer: for advance(tokenizer) == nil {
		#partial switch t in tokenizer.token {
		case Identifier:
			key := tokenizer.token.(Identifier)

			advance(tokenizer) or_return
			assert_type(tokenizer, Symbol) or_return
			assert_symbol(tokenizer, .Equal) or_return

			advance(tokenizer) or_return

			append(&tokenizer.pairs, Pair{key = key, value = tokenizer.token})
		case Keyword:
			#partial switch tokenizer.token.(Keyword) {
			case .Indicator:
				advance(tokenizer) or_return
				assert_type(tokenizer, Number) or_return
				key := Indicator(tokenizer.token.(Number))

				advance(tokenizer) or_return
				assert_type(tokenizer, Symbol) or_return
				assert_symbol(tokenizer, .Equal) or_return

				advance(tokenizer) or_return
				assert_type(tokenizer, String) or_return

				append(&tokenizer.pairs, Pair{key = key, value = tokenizer.token})
			case .Alias:
				advance(tokenizer) or_return
				assert_type(tokenizer, Identifier) or_return
				key := Alias(tokenizer.token.(Identifier))

				advance(tokenizer) or_return
				assert_type(tokenizer, Symbol) or_return
				assert_symbol(tokenizer, .Equal)

				advance(tokenizer) or_return
				assert_type(tokenizer, Identifier) or_return

				append(&tokenizer.pairs, Pair{key = key, value = tokenizer.token.(Identifier)})
			}
		case Symbol:
			assert_symbol(tokenizer, .BraceClose) or_return
			break outer
		case:
			fmt.println("OTHER TYPE")
		}

		advance(tokenizer) or_return
		assert_type(tokenizer, Symbol) or_return
		assert_symbol(tokenizer, .Semicolon) or_return
	}

	advance(tokenizer) or_return
	assert_type(tokenizer, Symbol) or_return
	assert_symbol(tokenizer, .Semicolon) or_return

	return nil
}

@(private = "file")
parse_types :: proc(tokenizer: ^Tokenizer) -> Error {
	advance(tokenizer) or_return
	assert_type(tokenizer, Keyword) or_return
	assert_keyword(tokenizer, .Types) or_return

	advance(tokenizer) or_return
	assert_type(tokenizer, String) or_return

	advance(tokenizer) or_return
	assert_type(tokenizer, Symbol) or_return
	assert_symbol(tokenizer, .BraceOpen) or_return

	advance(tokenizer) or_return
	assert_type(tokenizer, Identifier) or_return
	assert_identifier(tokenizer, Identifier(virtual_modifiers[:]))

	advance(tokenizer) or_return

	for assert_type(tokenizer, Identifier) == nil {
		advance(tokenizer) or_return
		assert_type(tokenizer, Symbol) or_return

		if assert_symbol(tokenizer, .Semicolon) == nil do break
		advance(tokenizer) or_return
	}

	advance(tokenizer) or_return
	for assert_type(tokenizer, Identifier) == nil {
		advance(tokenizer) or_return
		assert_type(tokenizer, String) or_return

		advance(tokenizer) or_return
		assert_type(tokenizer, Symbol) or_return
		assert_symbol(tokenizer, .BraceOpen) or_return

		advance(tokenizer) or_return
		for assert_type(tokenizer, Identifier) == nil {
			f: for {
				if assert_type(tokenizer, Symbol) == nil {
					if assert_symbol(tokenizer, .Semicolon) == nil do break
				}

				advance(tokenizer) or_return
			}

			advance(tokenizer) or_return
		}

		assert_type(tokenizer, Symbol) or_return
		assert_symbol(tokenizer, .BraceClose) or_return
		advance(tokenizer) or_return

		assert_type(tokenizer, Symbol) or_return
		assert_symbol(tokenizer, .Semicolon) or_return
		advance(tokenizer) or_return
	}

	assert_type(tokenizer, Symbol) or_return
	assert_symbol(tokenizer, .BraceClose) or_return

	advance(tokenizer) or_return

	assert_type(tokenizer, Symbol) or_return
	assert_symbol(tokenizer, .Semicolon) or_return

	return nil
}

parse_compatibility :: proc(tokenizer: ^Tokenizer) -> Error {
	advance(tokenizer) or_return
	assert_type(tokenizer, Keyword) or_return
	assert_keyword(tokenizer, .Compatibility) or_return

	advance(tokenizer) or_return
	assert_type(tokenizer, String) or_return

	advance(tokenizer) or_return
	assert_type(tokenizer, Symbol) or_return
	assert_symbol(tokenizer, .BraceOpen) or_return

	advance(tokenizer) or_return
	assert_type(tokenizer, Identifier) or_return
	assert_identifier(tokenizer, Identifier(virtual_modifiers[:]))

	advance(tokenizer) or_return

	for assert_type(tokenizer, Identifier) == nil {
		advance(tokenizer) or_return
		assert_type(tokenizer, Symbol) or_return

		if assert_symbol(tokenizer, .Semicolon) == nil do break
		advance(tokenizer) or_return
	}

	advance(tokenizer) or_return
	for assert_type(tokenizer, Symbol) != nil {
		#partial switch t in tokenizer.token {
		case Identifier:
			advance(tokenizer) or_return

			#partial switch to in tokenizer.token {
			case Symbol:
				assert_symbol(tokenizer, .Dot) or_return

				advance(tokenizer) or_return
				assert_type(tokenizer, Identifier) or_return

				advance(tokenizer) or_return
				assert_type(tokenizer, Symbol) or_return
				assert_symbol(tokenizer, .Equal) or_return

				advance(tokenizer) or_return
				assert_type(tokenizer, Identifier) or_return
			case Identifier:
				for {
					if assert_type(tokenizer, Symbol) == nil {
						if assert_symbol(tokenizer, .BraceOpen) == nil do break
					}

					advance(tokenizer) or_return
				}

				advance(tokenizer) or_return
				for {
					if assert_type(tokenizer, Symbol) == nil {
						if assert_symbol(tokenizer, .BraceClose) == nil do break
					}

					advance(tokenizer) or_return
				}
			}
		case Keyword:
			assert_keyword(tokenizer, .Indicator) or_return

			advance(tokenizer) or_return
			assert_type(tokenizer, String) or_return

			advance(tokenizer) or_return
			assert_type(tokenizer, Symbol) or_return
			assert_symbol(tokenizer, .BraceOpen) or_return

			for {
				if assert_type(tokenizer, Symbol) == nil {
					if assert_symbol(tokenizer, .BraceClose) == nil do break
				}

				advance(tokenizer) or_return
			}
		}

		advance(tokenizer) or_return
		assert_type(tokenizer, Symbol) or_return
		assert_symbol(tokenizer, .Semicolon) or_return
		advance(tokenizer) or_return
	}

	advance(tokenizer) or_return
	assert_type(tokenizer, Symbol) or_return
	assert_symbol(tokenizer, .Semicolon) or_return

	return nil
}

parse_symbols :: proc(tokenizer: ^Tokenizer, allocator: runtime.Allocator) -> Error {

	advance(tokenizer) or_return
	assert_type(tokenizer, Keyword) or_return
	assert_keyword(tokenizer, .Symbols) or_return

	advance(tokenizer) or_return
	assert_type(tokenizer, String) or_return

	advance(tokenizer) or_return
	assert_type(tokenizer, Symbol)
	assert_symbol(tokenizer, .BraceOpen) or_return

	for {
		if assert_type(tokenizer, Symbol) == nil {
			if assert_symbol(tokenizer, .Semicolon) == nil {
				break
			}
		}

		advance(tokenizer) or_return
	}

	advance(tokenizer) or_return

	tokenizer.tokens = make([dynamic]Token, 0, 1000, allocator)
	tokenizer.codes = make([dynamic]KeyCode, 0, 500, allocator)

	for assert_type(tokenizer, Identifier) == nil {
		if assert_identifier(tokenizer, Identifier(key_word[:])) == nil {
			parse_key(tokenizer, false, allocator) or_return
		} else if assert_identifier(tokenizer, Identifier(modifier_map_word[:])) == nil {
			parse_key(tokenizer, true, allocator) or_return
		} else {
			panic("SHOULD NOT BE HERE")
		}

		advance(tokenizer) or_return
	}

	assert_type(tokenizer, Symbol) or_return
	assert_symbol(tokenizer, .BraceClose) or_return

	advance(tokenizer) or_return
	assert_type(tokenizer, Symbol) or_return
	assert_symbol(tokenizer, .Semicolon) or_return

	return nil
}

parse_key :: proc(tokenizer: ^Tokenizer, is_array: bool, allocator: runtime.Allocator) -> Error {
	code: KeyCode
	advance(tokenizer) or_return
	code.key = tokenizer.token.(Identifier)
	start := len(tokenizer.tokens)

	advance(tokenizer) or_return
	assert_type(tokenizer, Symbol) or_return
	assert_symbol(tokenizer, .BraceOpen) or_return

	advance(tokenizer) or_return
	#partial switch _ in tokenizer.token {
	case Identifier:
		if is_array {
			parse_key_symbols(tokenizer) or_return
			break
		}

		assert_identifier(tokenizer, Identifier(type_word[:])) or_return

		advance(tokenizer) or_return
		assert_type(tokenizer, Symbol) or_return
		assert_symbol(tokenizer, .Equal) or_return

		advance(tokenizer) or_return
		assert_type(tokenizer, String) or_return

		advance(tokenizer) or_return
		assert_type(tokenizer, Symbol) or_return
		assert_symbol(tokenizer, .Comma) or_return

		advance(tokenizer) or_return
		assert_type(tokenizer, Identifier) or_return
		assert_identifier(tokenizer, Identifier(symbols_word[:])) or_return

		advance(tokenizer) or_return
		assert_type(tokenizer, Symbol) or_return
		assert_symbol(tokenizer, .SquareOpen)
		advance(tokenizer) or_return

		index := tokenizer.token.(Identifier)

		advance(tokenizer) or_return
		assert_type(tokenizer, Symbol) or_return
		assert_symbol(tokenizer, .SquareClose)

		advance(tokenizer) or_return
		assert_type(tokenizer, Symbol) or_return
		assert_symbol(tokenizer, .Equal)
		advance(tokenizer) or_return

		assert_symbol(tokenizer, .SquareOpen) or_return

		advance(tokenizer) or_return
		parse_key_symbols(tokenizer) or_return

		assert_symbol(tokenizer, .SquareClose) or_return
		advance(tokenizer) or_return
	case Symbol:
		assert_symbol(tokenizer, .SquareOpen) or_return

		advance(tokenizer) or_return
		parse_key_symbols(tokenizer) or_return

		assert_symbol(tokenizer, .SquareClose) or_return
		advance(tokenizer) or_return
	}

	code.values = tokenizer.tokens[start:]
	append(&tokenizer.codes, code)

	assert_type(tokenizer, Symbol) or_return
	assert_symbol(tokenizer, .BraceClose) or_return

	advance(tokenizer) or_return
	assert_type(tokenizer, Symbol) or_return
	assert_symbol(tokenizer, .Semicolon) or_return

	return nil
}

parse_key_symbols :: proc(tokenizer: ^Tokenizer) -> Error {
	for {
		if assert_type(tokenizer, Symbol) == nil do return .TypeAssertionFailed
		append(&tokenizer.tokens, tokenizer.token)

		advance(tokenizer) or_return
		if assert_type(tokenizer, Symbol) == nil {
			if assert_symbol(tokenizer, .Comma) == nil {
				advance(tokenizer) or_return
			} else {
				break
			}
		}
	}


	return nil
}

@(private = "file")
assert_identifier :: proc(tokenizer: ^Tokenizer, identifier: Identifier) -> Error {
	if !eql(([]u8)(tokenizer.token.(Identifier)), ([]u8)(identifier)) {
		// fmt.println(
		// 	string(([]u8)(tokenizer.token.(Identifier))),
		// 	"AGAINST",
		// 	string(([]u8)(identifier)),
		// )
		return .IdentifierAssertionFailed
	}

	return nil
}

@(private = "file")
assert_keyword :: proc(tokenizer: ^Tokenizer, keyword: Keyword) -> Error {
	if tokenizer.token.(Keyword) != keyword do return .KeywordAssertionFailed

	return nil

}

@(private = "file")
assert_symbol :: proc(tokenizer: ^Tokenizer, symbol: Symbol) -> Error {
	if tokenizer.token.(Symbol) != symbol {
		return .SymbolAssertionFailed
	}

	return nil
}

@(private = "file")
assert_type :: proc(tokenizer: ^Tokenizer, $T: typeid) -> Error {
	t, ok := tokenizer.token.(T)

	if !ok {
		// fmt.println("FAILED", tokenizer.token, "TRYING", typeid_of(T))
		return .TypeAssertionFailed
	}

	return nil
}

@(private = "file")
advance :: proc(tokenizer: ^Tokenizer) -> Error {
	tokenizer.token = next(tokenizer)

	if tokenizer.token == nil do return .Eof

	return nil

}

@(private = "file")
next :: proc(tokenizer: ^Tokenizer) -> Token {
	skip_whitespace(tokenizer)

	if at_end(tokenizer) do return nil
	if is_number(tokenizer.bytes[tokenizer.offset]) {
		start := tokenizer.offset
		for !at_end(tokenizer) && is_number(tokenizer.bytes[tokenizer.offset]) {
			tokenizer.offset += 1
		}

		return Number(to_number(tokenizer.bytes[start:tokenizer.offset]))
	} else if is_ascci(tokenizer.bytes[tokenizer.offset]) {
		start := tokenizer.offset
		for !at_end(tokenizer) && is_ascci(tokenizer.bytes[tokenizer.offset]) {
			tokenizer.offset += 1
		}

		bytes := tokenizer.bytes[start:tokenizer.offset]

		if keyword := get_keyword(bytes); keyword != nil do return keyword.?

		return Identifier(bytes)
	} else {
		start := tokenizer.offset
		tokenizer.offset += 1

		switch tokenizer.bytes[start] {
		case '<':
			for !at_end(tokenizer) && tokenizer.bytes[tokenizer.offset] != '>' {
				tokenizer.offset += 1
			}

			defer tokenizer.offset += 1
			return Identifier(tokenizer.bytes[start + 1:tokenizer.offset])
		case '(':
			return .ParenOpen
		case ')':
			return .ParenClose
		case '{':
			return .BraceOpen
		case '}':
			return .BraceClose
		case '[':
			return .SquareOpen
		case ']':
			return .SquareClose
		case ';':
			return .Semicolon
		case ',':
			return .Comma
		case '-':
			return .Minus
		case '+':
			return .Plus
		case '.':
			return .Dot
		case '=':
			return .Equal
		case '!':
			return .Bang
		case '"':
			start = tokenizer.offset

			for !at_end(tokenizer) && tokenizer.bytes[tokenizer.offset] != '"' {
				tokenizer.offset += 1
			}

			defer tokenizer.offset += 1
			return String(tokenizer.bytes[start:tokenizer.offset])
		}
	}

	return nil
}

@(private = "file")
skip_whitespace :: proc(tokenizer: ^Tokenizer) {
	for !at_end(tokenizer) && tokenizer.bytes[tokenizer.offset] == '\n' {
		tokenizer.line += 1
		tokenizer.offset += 1
	}

	for !at_end(tokenizer) &&
	    (tokenizer.bytes[tokenizer.offset] == ' ' || tokenizer.bytes[tokenizer.offset] == '\t') {
		tokenizer.offset += 1
	}
}

@(private = "file")
get_keyword :: proc(bytes: []u8) -> Maybe(Keyword) {
	if eql(indicator[:], bytes) do return .Indicator
	if eql(alias[:], bytes) do return .Alias
	if eql(xkb_keymap[:], bytes) do return .Keymap
	if eql(xkb_keycodes[:], bytes) do return .Keycodes
	if eql(xkb_types[:], bytes) do return .Types
	if eql(xkb_compatibility[:], bytes) do return .Compatibility
	if eql(xkb_symbols[:], bytes) do return .Symbols

	return nil

}

eql :: proc(first: []u8, second: []u8) -> bool {
	if len(first) != len(second) do return false

	for i in 0 ..< len(first) {
		if first[i] != second[i] do return false
	}

	return true
}


@(private = "file")
at_end :: proc(tokenizer: ^Tokenizer) -> bool {
	return tokenizer.offset >= u32(len(tokenizer.bytes))
}

@(private = "file")
is_number :: proc(u: u8) -> bool {
	return u >= '0' && u <= '9'
}

@(private = "file")
to_number :: proc(bytes: []u8) -> u32 {
	number: u32

	for b in bytes {
		number *= 10
		number += u32(b) - '0'
	}

	return number
}

@(private = "file")
is_ascci :: proc(u: u8) -> bool {
	return (u >= 'a' && u <= 'z') || (u >= 'A' && u <= 'Z') || is_number(u) || u == '_'
}

Error :: enum {
	OutOfMemory,
	FileNotFound,
	ReadFileFailed,
	AttributeKindNotFound,
	NumberParseFailed,
	CreateInstanceFailed,
	CreateBuffer,
	BeginCommandBufferFailed,
	EndCommandBufferFailed,
	AllocateCommandBufferFailed,
	VulkanLib,
	LayerNotFound,
	PhysicalDeviceNotFound,
	FamilyIndiceNotComplete,
	MemoryNotFound,
	EnviromentVariablesNotSet,
	WaylandSocketNotAvaiable,
	SendMessageFailed,
	BufferNotReleased,
	CreateDescriptorSetLayoutFailed,
	CreatePipelineFailed,
	GetImageModifier,
	AllocateDeviceMemory,
	CreateImageFailed,
	WaitFencesFailed,
	QueueSubmitFailed,
	CreateImageViewFailed,
	CreatePipelineLayouFailed,
	CreateDescriptorPoolFailed,
	CreateFramebufferFailed,
	GetFdFailed,
	SizeNotMatch,
	CreateShaderModuleFailed,
	AllocateDescriptorSetFailed,
	ExtensionNotFound,
	CreateDeviceFailed,
	CreateRenderPassFailed,
	CreateSemaphoreFailed,
	CreateFenceFailed,
	CreateCommandPoolFailed,
	SocketConnectFailed,
	GltfLoadFailed,
	InvalidKeymapInput,
	TypeAssertionFailed,
	IdentifierAssertionFailed,
	KeywordAssertionFailed,
	SymbolAssertionFailed,
	Eof,
}

key_word := [?]u8{'k', 'e', 'y'}
type_word := [?]u8{'t', 'y', 'p', 'e'}
symbols_word := [?]u8{'s', 'y', 'm', 'b', 'o', 'l', 's'}
modifier_map_word := [?]u8{'m', 'o', 'd', 'i', 'f', 'i', 'e', 'r', '_', 'm', 'a', 'p'}
interpret := [?]u8{'i', 'n', 't', 'e', 'r', 'p', 'r', 'e', 't'}
indicator := [?]u8{'i', 'n', 'd', 'i', 'c', 'a', 't', 'o', 'r'}
alias := [?]u8{'a', 'l', 'i', 'a', 's'}
virtual_modifiers := [?]u8 {
	'v',
	'i',
	'r',
	't',
	'u',
	'a',
	'l',
	'\'',
	'_',
	'm',
	'o',
	'd',
	'i',
	'f',
	'i',
	'e',
	'r',
	's',
}
xkb_keymap := [?]u8{'x', 'k', 'b', '_', 'k', 'e', 'y', 'm', 'a', 'p'}
xkb_keycodes := [?]u8{'x', 'k', 'b', '_', 'k', 'e', 'y', 'c', 'o', 'd', 'e', 's'}
xkb_types := [?]u8{'x', 'k', 'b', '_', 't', 'y', 'p', 'e', 's'}
xkb_symbols := [?]u8{'x', 'k', 'b', '_', 's', 'y', 'm', 'b', 'o', 'l', 's'}
xkb_compatibility := [?]u8 {
	'x',
	'k',
	'b',
	'_',
	'c',
	'o',
	'm',
	'p',
	'a',
	't',
	'i',
	'b',
	'i',
	'l',
	'i',
	't',
	'y',
}
