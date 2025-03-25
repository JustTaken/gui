package protocol
Int :: distinct i32
Uint :: distinct u32
Fixed :: distinct i32
Object :: distinct u32
BoundNewId :: distinct u32
Fd :: distinct i32
String :: distinct []u8
Array :: distinct []u8
UnBoundNewId :: struct {
  id: BoundNewId,
  interface: []u8,
}
ArgumentKind :: enum {
  Int,
  Uint,
  Fixed,
  Fd,
  Object,
  BoundNewId,
  UnBoundNewId,
  String,
  Array,
}
Argument :: union {
  Int,
  Uint,
  Fixed,
  Fd,
  Object,
  BoundNewId,
  UnBoundNewId,
  String,
  Array,
}
Request :: struct {
  name: string,
  arguments: []ArgumentKind,
}
Event :: struct {
  name: string,
  arguments: []ArgumentKind,
}
Interface :: struct {
  name: string,
  requests: []Request,
  events: []Event,
}
