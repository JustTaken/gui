package main

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:os"
import "core:testing"
import "core:unicode"

Identifier :: distinct []u8
String :: distinct []u8

Keyword :: enum {
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
	Eof,
}

Token :: union {
	Symbol,
	Identifier,
	String,
	Keyword,
}

Tokenizer :: struct {
	line:   u32,
	offset: u32,
	token:  Token,
	bytes:  []u8,
	pairs:  map[u32]u32,
	codes:  [dynamic]KeyCode,
	keys:   [dynamic]Code,
}

Keymap :: map[u32][]Code
// Keymap :: struct {
// pairs: map[u32]u32,
// codes: []KeyCode,
// }

KeyCode :: struct {
	key:    u32,
	values: []Code,
}

keymap_from_bytes :: proc(
	bytes: []u8,
	allocator: runtime.Allocator,
) -> (
	keymap: Keymap,
	err: Error,
) {
	keymap = parse_keymap(bytes, allocator) or_return

	return keymap, nil
}

// get_key_name_id :: proc(keymap: ^Keymap, name: string) -> (u32, Error) {
// 	bytes := transmute([]u8)name
// 	id := key_pair_from_identifier(Identifier(bytes))

// 	_, ok := keymap.pairs[id]

// 	if !ok {
// 		return 0, .UnregisteredKey
// 	}

// 	return id, nil
// }

get_code :: proc(keymap: Keymap, id: u32) -> Code {
	value, ok := keymap[id + 8]
	fmt.println("COMMING ID:", id, "GOT", value)

	if ok && len(value) > 0 {
		return value[0]
	} else {
		return nil
	}
}

@(private = "file")
parse_keymap :: proc(bytes: []u8, allocator: runtime.Allocator) -> (keymap: Keymap, err: Error) {
	tokenizer := Tokenizer {
		bytes  = bytes,
		offset = 0,
		line   = 0,
	}

	advance(&tokenizer) or_return
	assert_type(&tokenizer, Keyword) or_return
	assert_keyword(&tokenizer, .Keymap) or_return

	advance(&tokenizer) or_return
	assert_type(&tokenizer, Symbol) or_return
	assert_symbol(&tokenizer, .BraceOpen) or_return

	for advance(&tokenizer) == nil {
		assert_type(&tokenizer, Keyword) or_break

		#partial switch tokenizer.token.(Keyword) {
		case .Keycodes:
			parse_keycodes(&tokenizer, allocator) or_return
		case .Types:
			parse_types(&tokenizer) or_return
		case .Compatibility:
			parse_compatibility(&tokenizer) or_return
		case .Symbols:
			parse_symbols(&tokenizer, allocator) or_return
		case:
			return nil, .KeywordAssertionFailed
		}
	}

	keymap = make(map[u32][]Code, 100, allocator)
	for code in tokenizer.codes[:] {
		id := tokenizer.pairs[code.key]
		keymap[id] = code.values
		fmt.println("Registering:", id, code.values)
	}

	return keymap, nil
}

@(private = "file")
key_pair_from_identifier :: proc(identifier: Identifier) -> u32 {
	key: u32 = 0
	for i in 0 ..< len(identifier) {
		key = u32(key << 8) + u32(identifier[i])
	}

	return key
}

@(private = "file")
parse_keycodes :: proc(tokenizer: ^Tokenizer, allocator: runtime.Allocator) -> Error {
	advance(tokenizer) or_return
	assert_type(tokenizer, String) or_return

	advance(tokenizer) or_return
	assert_type(tokenizer, Symbol) or_return
	assert_symbol(tokenizer, .BraceOpen) or_return

	tokenizer.pairs = make(map[u32]u32, 1000, allocator)

	outer: for advance(tokenizer) == nil {
		#partial switch t in tokenizer.token {
		case Identifier:
			if assert_identifier(tokenizer, Identifier(indicator[:])) == nil {
				advance(tokenizer) or_return
				assert_type(tokenizer, Identifier) or_return

				advance(tokenizer) or_return
				assert_type(tokenizer, Symbol) or_return
				assert_symbol(tokenizer, .Equal) or_return

				advance(tokenizer) or_return
				assert_type(tokenizer, String) or_return

			} else if assert_identifier(tokenizer, Identifier(alias[:])) == nil {
				advance(tokenizer) or_return
				assert_type(tokenizer, Identifier) or_return
				key := key_pair_from_identifier(tokenizer.token.(Identifier))

				advance(tokenizer) or_return
				assert_type(tokenizer, Symbol) or_return
				assert_symbol(tokenizer, .Equal)

				advance(tokenizer) or_return
				assert_type(tokenizer, Identifier) or_return

				value := key_pair_from_identifier(tokenizer.token.(Identifier))

				tokenizer.pairs[key] = tokenizer.pairs[value]
			} else {
				key := key_pair_from_identifier(tokenizer.token.(Identifier))

				advance(tokenizer) or_return
				assert_type(tokenizer, Symbol) or_return
				assert_symbol(tokenizer, .Equal) or_return

				advance(tokenizer) or_return

				tokenizer.pairs[key] = to_number(tokenizer.token.(Identifier))
			}
		case Symbol:
			assert_symbol(tokenizer, .BraceClose) or_return
			break outer
		case:
			log.info("OTHER TYPE")
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

@(private = "file")
parse_compatibility :: proc(tokenizer: ^Tokenizer) -> Error {
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
			if assert_identifier(tokenizer, Identifier(indicator[:])) == nil {
				advance(tokenizer) or_return
				assert_type(tokenizer, String) or_return

				advance(tokenizer) or_return
				assert_type(tokenizer, Symbol) or_return
				assert_symbol(tokenizer, .BraceOpen) or_return

				advance(tokenizer) or_return
				for {
					if assert_type(tokenizer, Symbol) == nil {
						if assert_symbol(tokenizer, .BraceClose) == nil do break
					}

					advance(tokenizer) or_return
				}
			} else {
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

@(private = "file")
parse_symbols :: proc(tokenizer: ^Tokenizer, allocator: runtime.Allocator) -> Error {
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

	tokenizer.keys = make([dynamic]Code, 0, 1000, allocator)
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

@(private = "file")
parse_key :: proc(tokenizer: ^Tokenizer, is_array: bool, allocator: runtime.Allocator) -> Error {
	code: KeyCode
	advance(tokenizer) or_return
	code.key = key_pair_from_identifier(tokenizer.token.(Identifier))
	start := len(tokenizer.keys)

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

	code.values = tokenizer.keys[start:]
	append(&tokenizer.codes, code)

	assert_type(tokenizer, Symbol) or_return
	assert_symbol(tokenizer, .BraceClose) or_return

	advance(tokenizer) or_return
	assert_type(tokenizer, Symbol) or_return
	assert_symbol(tokenizer, .Semicolon) or_return

	return nil
}

@(private = "file")
parse_key_symbols :: proc(tokenizer: ^Tokenizer) -> Error {
	for {
		if assert_type(tokenizer, Symbol) == nil do return .TypeAssertionFailed

		code := code_from_token(tokenizer.token)
		log.info("Adding:", code)

		if code != nil {
			append(&tokenizer.keys, code)
		}

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
		return .TypeAssertionFailed
	}

	return nil
}

@(private = "file")
advance :: proc(tokenizer: ^Tokenizer) -> Error {
	tokenizer.token = next(tokenizer)

	if tokenizer.token == nil {
		return .InvalidToken
	}

	return nil
}

@(private = "file")
next :: proc(tokenizer: ^Tokenizer) -> Token {
	skip_whitespace(tokenizer)

	if at_end(tokenizer) do return .Eof

	if is_ascci(tokenizer.bytes[tokenizer.offset]) {
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
		case:
			log.error("Wired char:", rune(tokenizer.bytes[start]))
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
to_number :: proc(bytes: Identifier) -> u32 {
	number: u32

	for b in bytes {
		number *= 10
		number += u32(b) - '0'
	}

	return number
}

@(private = "file")
is_ascci :: proc(u: u8) -> bool {
	return is_lower_ascci(u) || is_upper_ascci(u) || is_number(u) || u == '_'
}

@(private = "file")
is_lower_ascci :: proc(u: u8) -> bool {
	return u >= 'a' && u <= 'z'
}

@(private = "file")
is_upper_ascci :: proc(u: u8) -> bool {
	return u >= 'A' && u <= 'Z'
}

@(private = "file")
code_from_token :: proc(token: Token) -> Code {
	#partial switch _ in token {
	case Identifier:
		iden := token.(Identifier)
		if len(iden) == 1 {
			c := Code(iden[0])
			fmt.println("FROM:", rune(iden[0]), iden[0], "GOT", c)
			return c
		}
	}

	return nil
}

Code :: enum {
	Space = 32,
	Exclamation,
	DoubleQuote,
	HashTag,
	DolarSign,
	Percent,
	And,
	Quote,
	ParenLeft,
	ParenRight,
	Star,
	Plus,
	Comma,
	Minus,
	Dot,
	Bar,
	Zero,
	One,
	Two,
	Three,
	Four,
	Five,
	Six,
	Seven,
	Eight,
	Nine,
	Doublecolon,
	Semicolon,
	LessThan,
	Equal,
	Greater,
	QuestioMark,
	At,
	A,
	B,
	C,
	D,
	E,
	F,
	G,
	H,
	I,
	J,
	K,
	L,
	M,
	N,
	O,
	P,
	Q,
	R,
	S,
	T,
	U,
	V,
	W,
	X,
	Y,
	Z,
	SquareLeft,
	CounterBar,
	SquareRight,
	Hat,
	Underscore,
	Grave,
	a,
	b,
	c,
	d,
	e,
	f,
	g,
	h,
	i,
	j,
	k,
	l,
	m,
	n,
	o,
	p,
	q,
	r,
	s,
	t,
	u,
	v,
	w,
	x,
	y,
	z,
	CurlyLeft,
	Pipe,
	CurlyRight,
	Tilde,
	Del,
}

key_word := [?]u8{'k', 'e', 'y'}
type_word := [?]u8{'t', 'y', 'p', 'e'}
symbols_word := [?]u8{'s', 'y', 'm', 'b', 'o', 'l', 's'}
modifier_map_word := [?]u8{'m', 'o', 'd', 'i', 'f', 'i', 'e', 'r', '_', 'm', 'a', 'p'}
interpret := [?]u8{'i', 'n', 't', 'e', 'r', 'p', 'r', 'e', 't'}
alias := [?]u8{'a', 'l', 'i', 'a', 's'}
indicator := [?]u8{'i', 'n', 'd', 'i', 'c', 'a', 't', 'o', 'r'}
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

@(test)
keycodes_parse_test :: proc(t: ^testing.T) {
	ok: bool
	bytes: []u8
	keymap: Keymap

	err: Error
	content := `xkb_keymap {
		xkb_keycodes "(unnamed)" {
			minimum = 8;
			maximum = 708;
			<ESC>                = 9;
			<AE01>               = 10;
			<AE02>               = 11;
			<AE03>               = 12;
			<AE04>               = 13;
		};
	};`


	_, err = parse_keymap(transmute([]u8)(content), context.allocator)

	testing.expect(t, err == nil, "AN ERROR OCCOURED")
}

@(test)
symbols_parse_test :: proc(t: ^testing.T) {
	bytes: []u8
	keymap: Keymap

	err: Error
	content := `xkb_keymap {
		xkb_symbols "(unnamed)" {
		    name[Group1]="English (US)";

			key <ESC>                {	[          Escape ] };
			key <AE01>               {	[               1,          exclam ] };
			key <AE02>               {	[               2,              at ] };
			key <AE03>               {	[               3,      numbersign ] };
			key <AE04>               {	[               4,          dollar ] };
			key <AE05>               {	[               5,         percent ] };
			key <AE06>               {	[               6,     asciicircum ] };
			key <AE07>               {	[               7,       ampersand ] };
			key <AE08>               {	[               8,        asterisk ] };
			key <AE09>               {	[               9,       parenleft ] };
			key <AE10>               {	[               0,      parenright ] };
			key <AE11>               {	[           minus,      underscore ] };
			key <AE12>               {	[           equal,            plus ] };
			key <BKSP>               {	[       BackSpace,       BackSpace ] };
       };
    };`


	_, err = parse_keymap(transmute([]u8)(content), context.allocator)

	testing.expect(t, err == nil, "AN ERROR OCCOURED")
}


@(test)
compatility_parse_test :: proc(t: ^testing.T) {
	bytes: []u8
	keymap: Keymap

	err: Error
	content := `xkb_keymap {
		xkb_compatibility "(unnamed)" {
			virtual_modifiers NumLock,Alt,LevelThree,Super,LevelFive,Meta,Hyper,ScrollLock;

			interpret.useModMapMods= AnyLevel;
			interpret.repeat= False;
			interpret ISO_Level2_Latch+Exactly(Shift) {
				useModMapMods=level1;
				action= LatchMods(modifiers=Shift,clearLocks,latchToLock);
			};
			indicator "Shift Lock" {
				whichModState= locked;
				modifiers= Shift;
			};
			interpret Shift_Lock+AnyOf(Shift+Lock) {
				action= LockMods(modifiers=Shift);
			};
			interpret Num_Lock+AnyOf(all) {
				virtualModifier= NumLock;
				action= LockMods(modifiers=NumLock);
			};
			interpret ISO_Level3_Shift+AnyOf(all) {
				virtualModifier= LevelThree;
				useModMapMods=level1;
				action= SetMods(modifiers=LevelThree,clearLocks);
			};
			interpret ISO_Level3_Latch+AnyOf(all) {
				virtualModifier= LevelThree;
				useModMapMods=level1;
				action= LatchMods(modifiers=LevelThree,clearLocks,latchToLock);
			};
			interpret ISO_Level3_Lock+AnyOf(all) {
				virtualModifier= LevelThree;
				useModMapMods=level1;
				action= LockMods(modifiers=LevelThree);
			};
			interpret Alt_L+AnyOf(all) {
				virtualModifier= Alt;
				action= SetMods(modifiers=modMapMods,clearLocks);
			};
       };
    };`


	_, err = parse_keymap(transmute([]u8)(content), context.allocator)

	testing.expect(t, err == nil, "AN ERROR OCCOURED")
}

@(test)
types_parse_test :: proc(t: ^testing.T) {
	bytes: []u8
	keymap: Keymap

	err: Error
	content := `xkb_keymap {
		xkb_types "(unnamed)" {
			virtual_modifiers NumLock,Alt,LevelThree,Super,LevelFive,Meta,Hyper,ScrollLock;

			type "ONE_LEVEL" {
				modifiers= none;
				level_name[1]= "Any";
			};
			type "TWO_LEVEL" {
				modifiers= Shift;
				map[Shift]= 2;
				level_name[1]= "Base";
				level_name[2]= "Shift";
			};
			type "ALPHABETIC" {
				modifiers= Shift+Lock;
				map[Shift]= 2;
				map[Lock]= 2;
				level_name[1]= "Base";
				level_name[2]= "Caps";
			};
       };
    };`


	_, err = parse_keymap(transmute([]u8)(content), context.allocator)

	testing.expect(t, err == nil, "AN ERROR OCCOURED")
}

@(test)
entire_file_test :: proc(t: ^testing.T) {
	ok: bool
	bytes: []u8
	keymap: Keymap
	err: Error
	id: u32

	bytes, ok = os.read_entire_file("output.txt")
	keymap, err = keymap_from_bytes(bytes, context.allocator)

	testing.expect(t, err == nil, "KEYMAP CREATION FAILED")

	// id, err = get_key_name_id(&keymap, "VOL+")

	// testing.expect(t, err == nil, "ID FAILED")
}
