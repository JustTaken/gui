#+build linux
#+private
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

usage :: proc() {
  fmt.println("Usage:")
  fmt.println(" ", os.args[0], "{input_path} {output_path} {package name}")
}

main :: proc() {
  l := len(os.args)
  output := make([dynamic]u8, 0, 1024 * 64)
  output_path: string

  if l == 3 {
    output_path = os.args[1]
    package_name := os.args[2]

    write_preambule(&output, package_name)
  } else if l == 4 {
    input_path := os.args[1]
    output_path = os.args[2]
    package_name := os.args[3]

    scan(&output, input_path, package_name, context.allocator)
  } else {
    usage()
    return
  }

  os.write_entire_file(output_path, output[:])
}

write_preambule :: proc(output: ^[dynamic]u8, package_name: string) {
  copy(output, "package ")
  copy(output, package_name)
  copy(output, "\n")

  copy_composed(output, "ArgumentKind", "enum", { "Int", "Uint", "Fixed", "String", "Object", "BoundNewId", "UnBoundNewId", "Array", "Fd" })
  copy_composed(output, "Request", "struct", { "name: string", "arguments: []ArgumentKind" })
  copy_composed(output, "Event", "struct", { "name: string", "arguments: []ArgumentKind" })
  copy_composed(output, "Interface", "struct", { "name: string", "requests: []Request", "events: []Event" })
}

scan :: proc(output: ^[dynamic]u8, input_path: string, package_name: string, allocator := context.allocator) -> bool {
  document: ^xml.Document
  err: xml.Error

  content, ok := os.read_entire_file(input_path, allocator = allocator)

  if !ok {
    fmt.println("Failed to open wayland xml")
    return false
  }

  document, err = xml.parse_bytes(content, allocator = allocator)

  if err != nil {
    fmt.println("Failed to parse xml document")
    return false
  }

  document, err = xml.parse_bytes(content, allocator = allocator)

  if err != nil {
    fmt.println("Failed to parse xml document")
    return false
  }

  requests := make([dynamic]^xml.Element, 0, 30)
  events := make([dynamic]^xml.Element, 0, 30)

  copy(output, "package ")
  copy(output, package_name)
  copy(output, "\n")

  copy(output, "interfaces := [?]Interface{\n")

  for value in document.elements[0].value {
    index := value.(u32)
    element := &document.elements[index] 

    if element.ident == "interface" {
      write_interface(output, element, &requests, &events, document.elements[:])
      clear(&requests)
      clear(&events)
    }
  }

  copy(output, "}\n")

  return true
}

write_interface :: proc(output: ^[dynamic]u8, element: ^xml.Element, requests: ^[dynamic]^xml.Element, events: ^[dynamic]^xml.Element, elements: []xml.Element) {
  if len(element.attribs) != 2 {
    return
  }

  ok: bool
  version: uint
  if version, ok = strconv.parse_uint(element.attribs[1].val, 10); !ok {
    return
  }

  for i in element.value {
    index := i.(u32) 
    element := &elements[index]

    if element.ident == "request" {
      append(requests, element)
    } else if elements[index].ident == "event" {
      append(events, element)
    }
  }

  copy(output, "  Interface{\n")
  copy(output, "    name = \"")
  copy(output, element.attribs[0].val)
  copy(output, "\",\n")

  write_requests(output, requests[:], elements)
  write_events(output, events[:], elements)
  copy(output, "  },\n")
}

write_requests :: proc(output: ^[dynamic]u8, requests: []^xml.Element, elements: []xml.Element) {
  copy(output, "    requests = {\n")

  for request in requests {
    copy(output, "      Request{\n")
    copy(output, "        name = \"")
    copy(output, request.attribs[0].val)
    copy(output, "\",\n        arguments = { ")
    write_arguments(output, request, elements)
    copy(output, " }\n      },\n")
  }

  copy(output, "    },\n")
}

write_events :: proc(output: ^[dynamic]u8, events: []^xml.Element, elements: []xml.Element) {
  copy(output, "    events = {\n")

  for event in events {
    copy(output, "      Event{\n")
    copy(output, "        name = \"")
    copy(output, event.attribs[0].val)
    copy(output, "\",\n        arguments = { ")
    write_arguments(output, event, elements)
    copy(output, " }\n      },\n")
  }

  copy(output, "    },\n")
}

write_arguments :: proc(output: ^[dynamic]u8, element: ^xml.Element, elements: []xml.Element) {
  count := 0
  for i in 0..<len(element.value) {
    argument_index := element.value[i].(u32)
    if elements[argument_index].ident != "arg" do continue

    if count > 0 {
      copy(output, ", ")
    }

    write_kind(output, elements[argument_index].attribs[:])
    count += 1
  }
}

write_kind :: proc(output: ^[dynamic]u8, attribs: []xml.Attribute) {
  switch attribs[1].val {
    case "new_id": 
      if attribs[2].key == "interface" {
        copy(output, ".BoundNewId")
      } else {
        copy(output, ".UnBoundNewId")
      }
    case "int": copy(output, ".Int")
    case "uint": copy(output, ".Uint")
    case "fixed": copy(output, ".Fixed")
    case "object": copy(output, ".Object")
    case "fd": copy(output, ".Fd")
    case "string": copy(output, ".String")
    case "array": copy(output, ".Array")
    case: copy(output, "Unknow")
  }
}

copy :: proc(dst: ^[dynamic]u8, src: string) {
  for s in src {
    append(dst, u8(s))
  }
}

copy_composed :: proc(dst: ^[dynamic]u8, name: string, kind: string, values: []string) {
  copy(dst, name)
  copy(dst, " :: ")
  copy(dst, kind)
  copy(dst, " {\n")

  for value in values {
    copy(dst, "  ")
    copy(dst, value)
    copy(dst, ",\n")
  }

  copy(dst, "}\n")
}

// new_connection :: proc(path: string, allocator := context.allocator) -> (Connection, bool) {
//   connection: Connection
//   document: ^xml.Document
//   err: xml.Error
// 
//   content, ok := os.read_entire_file(path, allocator = allocator)
// 
//   if !ok {
//     fmt.println("Failed to open wayland xml")
//     return connection, false
//   }
// 
//   document, err = xml.parse_bytes(content, allocator = allocator)
// 
//   if err != nil {
//     fmt.println("Failed to parse xml document")
//     return connection, false
//   }
// 
//   interfaces := make([dynamic]Interface, 0, 30, allocator = allocator)
//   requests := make([dynamic]Request, 0, 30 * 3, allocator = allocator)
//   events := make([dynamic]Event, 0, 30 * 3, allocator = allocator)
//   arguments := make([dynamic]ArgumentKind, 0, 120 * 3, allocator = allocator)
// 
//   for value in document.elements[0].value {
//     index := value.(u32)
//     element := &document.elements[index] 
// 
//     if element.ident == "interface" {
//       interface, success := parse_interface(element, &requests, &events, &arguments, document.elements[:])
// 
//       if !success {
//         panic("Failed to parse interface")
//       }
// 
//       append(&interfaces, interface)
//     }
//   }
// 
//   connection.interfaces = interfaces[:]
//   return connection, true
// }

// @(private)
// parse_interface :: proc(element: ^xml.Element, requests: ^[dynamic]Request, events: ^[dynamic]Event, arguments: ^[dynamic]ArgumentKind, elements: []xml.Element) -> (Interface, bool) {
//   interface: Interface
// 
//   if len(element.attribs) != 2 {
//     return interface, false
//   }
// 
//   ok: bool
//   if interface.version, ok = strconv.parse_uint(element.attribs[1].val, 10); !ok {
//     return interface, false
//   }
// 
//   request_start := len(requests)
//   event_start := len(events)
//   interface.name = element.attribs[0].val[3:]
// 
//   for i in element.value {
//     index := i.(u32) 
//     element := &elements[index]
// 
//     if element.ident == "request" {
//       append(requests, Request {
//         name = element.attribs[0].val,
//         arguments = parse_arguments(element, arguments, elements),
//       })
//     } else if elements[index].ident == "event" {
//       append(events, Event {
//         name = element.attribs[0].val,
//         arguments = parse_arguments(element, arguments, elements),
//       })
//     }
//   }
// 
//   interface.requests = requests[request_start:]
//   interface.events = events[event_start:]
// 
//   fmt.println(interface)
// 
//   return interface, true
// }
// 
// @(private)
// parse_function :: proc(element: ^xml.Element, arguments: ^[dynamic]ArgumentKind, elements: []xml.Element) -> (string, []ArgumentKind) {
//   return string(element.attribs[0].val), parse_arguments(element, arguments, elements)
// }
// 
// @(private)
// parse_arguments :: proc(element: ^xml.Element, arguments: ^[dynamic]ArgumentKind, elements: []xml.Element) -> []ArgumentKind {
//   start := len(arguments)
//   for index in 1..<len(element.value) {
//     append(arguments, parse_argument_kind(elements[element.value[index].(u32)].attribs[1].val))
//   }
// 
//   return arguments[start:]
// }
// 
// @(private)
// parse_argument_kind :: proc(typ: string) -> ArgumentKind {
//   switch typ {
//     case "new_id": return .NewId
//     case "int": return .Int
//     case "uint": return .Uint
//     case "fixed": return .Fixed
//     case "object": return .Object
//     case "fd": return .Fd
//     case "string": return .String
//     case "array": return .Array
//   }
// 
//   panic("Invalid argumentKind")
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
