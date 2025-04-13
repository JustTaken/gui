package main

import "core:fmt"
import "core:os"
import "core:unicode"

Identifier :: distinct []u8
String :: distinct []u8
Number :: u32

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

Keyword :: enum {
	Keycodes,
	Types,
	Compatibility,
	Symbols,
}

Token :: union {
	Identifier,
	Number,
	String,
	Symbol,
	Keyword,
}

Keymap :: struct {
}

main :: proc() {
	ok: bool
	bytes: []u8
	keymap: Keymap
	err: Error

	bytes, ok = os.read_entire_file("output.txt")
	keymap, err = keymap_from_bytes(bytes)

	if err != nil {
		fmt.println("Error", err)
	}
}

keymap_from_bytes :: proc(bytes: []u8) -> (Keymap, Error) {
	keymap: Keymap
	tokenizer := Tokenizer {
		bytes  = bytes,
		offset = 0,
	}


	token := next(&tokenizer)

	for token != nil {
		switch t in token {
		case Keyword:
			fmt.println("KEYWORD", token.(Keyword))
		case Identifier:
		// fmt.println("IDENTIFIER", string(token.(Identifier)))
		case Number:
		// fmt.println("NUMBER", token.(Number))
		case String:
		// fmt.println("STRING", string(token.(String)))
		case Symbol:
		// fmt.println("SYMBOL", token.(Symbol))
		}

		token = next(&tokenizer)
	}

	return keymap, nil
}

Tokenizer :: struct {
	offset: u32,
	bytes:  []u8,
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
		case '(':
			return .ParenOpen
		case ')':
			return .BraceClose
		case '{':
			return .BraceOpen
		case '}':
			return .ParenClose
		case '[':
			return .SquareOpen
		case ']':
			return .SquareClose
		case ';':
			return .Semicolon
		case ',':
			return .Comma
		case '<':
			return .Less
		case '>':
			return .Greater
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
	for !at_end(tokenizer) &&
	    (tokenizer.bytes[tokenizer.offset] == ' ' ||
			    tokenizer.bytes[tokenizer.offset] == '\n' ||
			    tokenizer.bytes[tokenizer.offset] == '\t') {
		tokenizer.offset += 1
	}
}

@(private = "file")
get_keyword :: proc(bytes: []u8) -> Maybe(Keyword) {
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
}

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
