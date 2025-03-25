package protocol

Int :: distinct i32
Uint :: distinct u32
Fixed :: distinct i32
Object :: distinct u32
NewId :: distinct u32
Fd :: distinct i32
Array :: distinct []u8
String :: distinct []u8

ArgumentKind :: enum {
  Int,
  Fixed,
  Uint,
  Object,
  NewId,
  Array,
  String,
  Fd,
}

Value :: union {
  Int,
  Fixed,
  Uint,
  Object,
  NewId,
  Array,
  String,
  Fd,
}

write :: proc(value: Value, kind: ArgumentKind) -> []u8 {
  return nil
}

read :: proc(bytes: []u8, kind: ArgumentKind) -> Value {
  return nil
}

Request :: struct {
  name: string,
  type: typeid,
}

Event :: struct {
  name: string,
  type: typeid,
}

Interface :: struct(R, E: typeid) {
  name: string,
  requests: R,
  events: E,
}

wl_display_request_get_registry :: struct {
  new_id: u32,
}

wl_display_request :: union {
  wl_display_request_get_registry,
}

wl_display :: struct {
  requests: wl_display_request
}

import "core:fmt"
main :: proc() {
}
