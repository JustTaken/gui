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

  copy_type(output, "Int", "distinct i32")
  copy_type(output, "Uint", "distinct u32")
  copy_type(output, "Fixed", "distinct i32")
  copy_type(output, "Object", "distinct u32")
  copy_type(output, "BoundNewId", "distinct u32")
  copy_type(output, "Fd", "distinct i32")
  copy_type(output, "String", "distinct []u8")
  copy_type(output, "Array", "distinct []u8")
  copy_composed(output, "UnBoundNewId", "struct", { "id: BoundNewId", "interface: string" })

  copy_composed(output, "ArgumentKind", "enum", { "Int", "Uint", "Fixed", "Fd", "Object", "BoundNewId", "UnBoundNewId", "String", "Array" })
  copy_composed(output, "Argument", "union", { "Int", "Uint", "Fixed", "Fd", "Object", "BoundNewId", "UnBoundNewId", "String", "Array" })
  copy_composed(output, "Request", "struct", { "name: string", "arguments: []ArgumentKind" })
  copy_composed(output, "Event", "struct", { "name: string", "arguments: []ArgumentKind" })
  copy_composed(output, "Interface", "struct", { "name: string", "requests: []Request", "events: []Event" })

  copy(output, "write :: proc(value: Argument, kind: ArgumentKind) -> []u8 {\n  return nil\n}\n")
  copy(output, "read :: proc(bytes: []u8, kind: ArgumentKind) -> Argument {\n  return nil\n}\n")
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

@(private)
copy_type :: proc(dst: ^[dynamic]u8, name: string, value: string) {
  copy(dst, name)
  copy(dst, " :: ")
  copy(dst, value)
  append(dst, u8('\n'))
}
