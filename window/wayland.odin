#+build linux
package window

import "core:os"
import xml "core:encoding/xml"
import fmt "core:fmt"
import "core:mem"
import "core:strconv"

ArgumentKind :: enum {
  Int, Uint, Fixed, Object, NewId, Fd, String, Array,
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
  version: uint,
  requests: []Request,
  events: []Event,
}

Connection :: struct {
  interfaces: []Interface,
}

main :: proc() {
  arena: mem.Arena
  bytes := make([]u8, 1024 * 1024 * 2)
  mem.arena_init(&arena, bytes)
  context.allocator = mem.arena_allocator(&arena)

  connection, ok := new_connection("assets/wayland.xml", context.allocator)

  if !ok {
    fmt.println("Failed to stablish connection")
    return
  }
}

new_connection :: proc(path: string, allocator := context.allocator) -> (Connection, bool) {
  connection: Connection
  document: ^xml.Document
  err: xml.Error

  content, ok := os.read_entire_file(path, allocator = allocator)

  if !ok {
    fmt.println("Failed to open wayland xml")
    return connection, false
  }

  document, err = xml.parse_bytes(content, allocator = allocator)

  if err != nil {
    fmt.println("Failed to parse xml document")
    return connection, false
  }

  interfaces := make([dynamic]Interface, 0, 30, allocator = allocator)
  requests := make([dynamic]Request, 0, 30 * 3, allocator = allocator)
  events := make([dynamic]Event, 0, 30 * 3, allocator = allocator)
  arguments := make([dynamic]ArgumentKind, 0, 120 * 3, allocator = allocator)

  for value in document.elements[0].value {
    index := value.(u32)
    element := &document.elements[index] 

    if element.ident == "interface" {
      interface, success := parse_interface(element, &requests, &events, &arguments, document.elements[:])

      if !success {
        panic("Failed to parse interface")
      }

      append(&interfaces, interface)
    }
  }

  connection.interfaces = interfaces[:]
  return connection, true
}

@(private)
parse_interface :: proc(element: ^xml.Element, requests: ^[dynamic]Request, events: ^[dynamic]Event, arguments: ^[dynamic]ArgumentKind, elements: []xml.Element) -> (Interface, bool) {
  interface: Interface

  if len(element.attribs) != 2 {
    return interface, false
  }

  ok: bool
  if interface.version, ok = strconv.parse_uint(element.attribs[1].val, 10); !ok {
    return interface, false
  }

  request_start := len(requests)
  event_start := len(events)
  interface.name = element.attribs[0].val[3:]

  request_count: u32 = 0
  for i in element.value {
    index := i.(u32) 
    element := &elements[index]

    if element.ident == "request" {
      append(requests, Request {
        name = element.attribs[0].val,
        arguments = parse_arguments(element, arguments, elements),
      })
    } else if elements[index].ident == "event" {
      append(events, Event {
        name = element.attribs[0].val,
        arguments = parse_arguments(element, arguments, elements),
      })
    }
  }

  interface.requests = requests[request_start:]
  interface.events = events[event_start:]

  fmt.println(interface)

  return interface, true
}

@(private)
parse_function :: proc(element: ^xml.Element, arguments: ^[dynamic]ArgumentKind, elements: []xml.Element) -> (string, []ArgumentKind) {
  return string(element.attribs[0].val), parse_arguments(element, arguments, elements)
}

@(private)
parse_arguments :: proc(element: ^xml.Element, arguments: ^[dynamic]ArgumentKind, elements: []xml.Element) -> []ArgumentKind {
  start := len(arguments)
  for index in 1..<len(element.value) {
    append(arguments, parse_argument_kind(elements[element.value[index].(u32)].attribs[1].val))
  }

  return arguments[start:]
}

@(private)
parse_argument_kind :: proc(typ: string) -> ArgumentKind {
  switch typ {
    case "new_id": return .NewId
    case "int": return .Int
    case "uint": return .Uint
    case "fixed": return .Fixed
    case "object": return .Object
    case "fd": return .Fd
    case "string": return .String
    case "array": return .Array
  }

  panic("Invalid argumentKind")
}

// write_requests :: proc(output: ^[dynamic]u8, prefix: string, requests: []xml.Element, elements: []xml.Element) {
//   copy(output, "    requests = {\n")
// 
//   for &request in requests {
//     copy(output, "      Request{\n")
//     copy(output, "        name = \"")
//     copy(output, request.attribs[0].val)
//     copy(output, "\",\n        args = { ")
//     write_arguments(output, &request, elements)
//     copy(output, " }\n      },\n")
//   }
// 
//   copy(output, "    },\n")
// }
// 
// write_events :: proc(output: ^[dynamic]u8, prefix: string, events: []xml.Element, elements: []xml.Element) {
//   copy(output, "    events = {\n")
// 
//   for &event in events {
//     copy(output, "      Event{\n")
//     copy(output, "        name = \"")
//     copy(output, event.attribs[0].val)
//     copy(output, "\",\n        args = { ")
//     write_arguments(output, &event, elements)
//     copy(output, " }\n      },\n")
//   }
// 
//   copy(output, "    },\n")
// }

// write_arguments :: proc(output: ^[dynamic]u8, element: ^xml.Element, elements: []xml.Element) {
//   for i in 1..<len(element.value) {
//     if i > 1 {
//       copy(output, ", ")
//     }
// 
//     append(output, u8('.'))
//     argument_index := element.value[i].(u32)
//     write_kind(output, elements[argument_index].attribs[1].val)
//   }
// }

// copy :: proc(dst: ^[dynamic]u8, src: string) {
//   for s in src {
//     append(dst, u8(s))
//   }
// }
// 
// copy_import :: proc(dst: ^[dynamic]u8, pkg: string) {
//   copy(dst, "import \"")
//   copy(dst, pkg)
//   copy(dst, "\"\n")
// }
// 
// copy_type :: proc(dst: ^[dynamic]u8, name: string, value: string) {
//   copy(dst, name)
//   copy(dst, " :: ")
//   copy(dst, value)
//   append(dst, u8('\n'))
// }
// 
// copy_composed :: proc(dst: ^[dynamic]u8, name: string, kind: string, values: []string) {
//   copy(dst, name)
//   copy(dst, " :: ")
//   copy(dst, kind)
//   copy(dst, " {\n")
// 
//   for value in values {
//     copy(dst, "  ")
//     copy(dst, value)
//     copy(dst, ",\n")
//   }
// 
//   copy(dst, "}\n")
// }
// 
// copy_function_start :: proc(dst: ^[dynamic]u8, name: string, parameters: []string) {
//   copy(dst, name)
//   copy(dst, "  :: proc(")
// 
//   for i in 0..<len(parameters) {
//     if i > 0 {
//       copy(dst, ", ")
//     }
// 
//     copy(dst, "  ")
//     copy(dst, parameters[i])
//   }
// 
//   copy(dst, ") {\n")
// }
// 
// copy_function_end :: proc(dst: ^[dynamic]u8) {
//   copy(dst, "}\n")
// }
// 
// copy_switch_start :: proc(dst: ^[dynamic]u8, expr: string) {
//   copy(dst, "  #partial switch ")
//   copy(dst, expr)
//   copy(dst, " {\n")
// }
// 
// copy_switch_end :: proc(dst: ^[dynamic]u8) {
//   copy(dst, "  }\n")
// }
// 
// copy_switch_case_start :: proc(dst: ^[dynamic]u8, expr: string) {
//   copy(dst, "  case ")
//   copy(dst, expr)
//   copy(dst, ":\n")
// }
// 
// copy_switch_case_inner :: proc(dst: ^[dynamic]u8, line: string) {
//   copy(dst, "    ")
//   copy(dst, line)
//   copy(dst, "\n")
// }
//
//  copy(&output, "package wayland_scan\n")
//  copy_import(&output, "core:mem")
//  copy_import(&output, "base:intrinsics")
//  copy_type(&output, "Int", "distinct i32")
//  copy_type(&output, "Fixed", "distinct i32")
//  copy_type(&output, "Uint", "distinct u32")
//  copy_type(&output, "String", "distinct []u8")
//  copy_type(&output, "Object", "distinct u32")
//  copy_type(&output, "Fd", "distinct i32")
//  copy_type(&output, "Array", "distinct []u8")
//  copy_composed(&output, "ArgumentKind", "enum", []string { "Int", "Uint", "Fixed", "String", "Object", "NewId", "Array", "Fd" })
//  copy_composed(&output, "Argument", "union", []string { "Int", "Uint", "Fixed", "String", "Object", "NewId", "Array", "Fd" })
//  copy_composed(&output, "Request", "struct", []string { "name: string", "args: []ArgumentKind" })
//  copy_composed(&output, "Event", "struct", []string { "name: string", "args: []ArgumentKind" })
//  copy_composed(&output, "Interface", "struct", []string { "name: string", "request: []Request, events: []Event" })
//
//  copy_function_start(&output, "read_argument", { "kind: ArgumentKind", "data: []u8" })
//  copy_switch_start(&output, "kind")
//  copy_switch_case_start(&output, ".Int")
//  copy_switch_case_inner(&output, "return intrinsics.unaligned_load((^Int)(rawptr(data))), size_of(Int)")
//  copy_switch_case_start(&output, ".Uint")
//  copy_switch_case_inner(&output, "return intrinsics.unaligned_load((^Uint)(rawptr(data))), size_of(Uint)")
//  copy_switch_case_start(&output, ".Fixed")
//  copy_switch_case_inner(&output, "return intrinsics.unaligned_load((^Fixed)(rawptr(data))), size_of(Fixed)")
//  copy_switch_case_start(&output, ".Object")
//  copy_switch_case_inner(&output, "return intrinsics.unaligned_load((^Object)(rawptr(data))), size_of(Object)")
//  copy_switch_case_start(&output, ".NewId")
//  copy_switch_case_inner(&output, "return intrinsics.unaligned_load((^NewId)(rawptr(data))), size_of(NewId)")
//  copy_switch_case_start(&output, ".String")
//  copy_switch_case_inner(&output, "unaligned_size := intrinsics.unaligned_load((^u32)(rawptr(data)))")
//  copy_switch_case_inner(&output, "return String(data[size_of(u32):unaligned_size - 1]), size_of(u32) + mem.align_formula(unaligned_size, size_of(u32))")
//  copy_switch_case_start(&output, ".Array")
//  copy_switch_case_inner(&output, "unaligned_size := intrinsics.unaligned_load((^u32)(rawptr(data)))")
//  copy_switch_case_inner(&output, "return Array(data[size_of(u32):unaligned_size - 1]), size_of(u32) + mem.align_formula(unaligned_size, size_of(u32))")
//  copy_switch_end(&output)
//  copy_function_end(&output)
//
//  copy_function_start(&output, "write_argument", { "arg: Argument", "output: ^[dynamic]u8" })
//  copy_switch_start(&output, "kind in arg")
//  copy_switch_case_start(&output, "Int")
//  copy_switch_case_inner(&output, "resize(output, size + size_of(Int))")
//  copy_switch_case_inner(&output, "intrinsics.unaligned_store((^Int)(rawptr(output[size:])), arg.(Int))")
//  copy_switch_case_start(&output, "Uint")
//  copy_switch_case_inner(&output, "resize(output, size + size_of(Uint))")
//  copy_switch_case_inner(&output, "intrinsics.unaligned_store((^Uint)(rawptr(output[size:])), arg.(Uint))")
//  copy_switch_case_start(&output, "Fixed")
//  copy_switch_case_inner(&output, "resize(output, size + size_of(Fixed))")
//  copy_switch_case_inner(&output, "intrinsics.unaligned_store((^Fixed)(rawptr(output[size:])), arg.(Fixed))")
//  copy_switch_case_start(&output, "Object")
//  copy_switch_case_inner(&output, "resize(output, size + size_of(Object))")
//  copy_switch_case_inner(&output, "intrinsics.unaligned_store((^Object)(rawptr(output[size:])), arg.(Object))")
//  copy_switch_case_start(&output, "NewId")
//  copy_switch_case_inner(&output, "resize(output, size + size_of(NewId))")
//  copy_switch_case_inner(&output, "intrinsics.unaligned_store((^NewId)(rawptr(output[size:])), arg.(NewId))")
//  copy_switch_case_start(&output, "String")
//  copy_switch_case_inner(&output, "bytes = arg.(String)")
//  copy_switch_case_inner(&output, "resize(output, size + size_of(u32) + mem.align_formula(len(bytes), size_of(u32)))")
//  copy_switch_case_inner(&output, "intrinsics.unaligned_store((^u32)(rawptr(output[size:])), len(bytes))")
//  copy_switch_case_inner(&output, "copy(output[size + size_of(u32):], bytes)")
//  copy_switch_case_start(&output, "Array")
//  copy_switch_case_inner(&output, "bytes = arg.(Array)")
//  copy_switch_case_inner(&output, "resize(output, size + size_of(u32) + mem.align_formula(len(bytes), size_of(u32)))")
//  copy_switch_case_inner(&output, "intrinsics.unaligned_store((^u32)(rawptr(output[size:])), len(bytes))")
//  copy_switch_case_inner(&output, "copy(output[size + size_of(u32):], bytes)")
//  copy_switch_end(&output)
//  copy_function_end(&output)
