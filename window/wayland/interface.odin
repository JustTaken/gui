package protocol
ArgumentKind :: enum {
  Int,
  Uint,
  Fixed,
  String,
  Object,
  BoundNewId,
  UnBoundNewId,
  Array,
  Fd,
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
