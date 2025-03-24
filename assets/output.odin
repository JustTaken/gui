package wayland_scan
import "core:mem"
import "base:intrinsics"
Int :: distinct i32
Fixed :: distinct i32
Uint :: distinct u32
String :: distinct []u8
Object :: distinct u32
Fd :: distinct i32
Array :: distinct []u8
ArgumentKind :: enum {
  Int,
  Uint,
  Fixed,
  String,
  Object,
  NewId,
  Array,
  Fd,
}
Argument :: union {
  Int,
  Uint,
  Fixed,
  String,
  Object,
  NewId,
  Array,
  Fd,
}
Request :: struct {
  name: string,
  args: []ArgumentKind,
}
Event :: struct {
  name: string,
  args: []ArgumentKind,
}
Interface :: struct {
  name: string,
  request: []Request, events: []Event,
}
read_argument  :: proc(  kind: ArgumentKind,   data: []u8) {
  #partial switch kind {
  case .Int:
    return intrinsics.unaligned_load((^Int)(rawptr(data))), size_of(Int)
  case .Uint:
    return intrinsics.unaligned_load((^Uint)(rawptr(data))), size_of(Uint)
  case .Fixed:
    return intrinsics.unaligned_load((^Fixed)(rawptr(data))), size_of(Fixed)
  case .Object:
    return intrinsics.unaligned_load((^Object)(rawptr(data))), size_of(Object)
  case .NewId:
    return intrinsics.unaligned_load((^NewId)(rawptr(data))), size_of(NewId)
  case .String:
    unaligned_size := intrinsics.unaligned_load((^u32)(rawptr(data)))
    return String(data[size_of(u32):unaligned_size - 1]), size_of(u32) + mem.align_formula(unaligned_size, size_of(u32))
  case .Array:
    unaligned_size := intrinsics.unaligned_load((^u32)(rawptr(data)))
    return Array(data[size_of(u32):unaligned_size - 1]), size_of(u32) + mem.align_formula(unaligned_size, size_of(u32))
  }
}
write_argument  :: proc(  arg: Argument,   output: ^[dynamic]u8) {
  #partial switch kind in arg {
  case Int:
    resize(output, size + size_of(Int))
    intrinsics.unaligned_store((^Int)(rawptr(output[size:])), arg.(Int))
  case Uint:
    resize(output, size + size_of(Uint))
    intrinsics.unaligned_store((^Uint)(rawptr(output[size:])), arg.(Uint))
  case Fixed:
    resize(output, size + size_of(Fixed))
    intrinsics.unaligned_store((^Fixed)(rawptr(output[size:])), arg.(Fixed))
  case Object:
    resize(output, size + size_of(Object))
    intrinsics.unaligned_store((^Object)(rawptr(output[size:])), arg.(Object))
  case NewId:
    resize(output, size + size_of(NewId))
    intrinsics.unaligned_store((^NewId)(rawptr(output[size:])), arg.(NewId))
  case String:
    bytes = arg.(String)
    resize(output, size + size_of(u32) + mem.align_formula(len(bytes), size_of(u32)))
    intrinsics.unaligned_store((^u32)(rawptr(output[size:])), len(bytes))
    copy(output[size + size_of(u32):], bytes)
  case Array:
    bytes = arg.(Array)
    resize(output, size + size_of(u32) + mem.align_formula(len(bytes), size_of(u32)))
    intrinsics.unaligned_store((^u32)(rawptr(output[size:])), len(bytes))
    copy(output[size + size_of(u32):], bytes)
  }
}
interfaces := [?]Interface {
  Interface{
    name = "display",
    requests = {
      Request{
        name = "sync",
        args = { .NewId    }
      },
      Request{
        name = "get_registry",
        args = { .NewId    }
      },
    },
    events = {
      Event{
        name = "error",
        args = { .Object, .Uint, .String    }
      },
      Event{
        name = "delete_id",
        args = { .Uint    }
      },
    },
  },
  Interface{
    name = "registry",
    requests = {
      Request{
        name = "bind",
        args = { .Uint, .NewId    }
      },
    },
    events = {
      Event{
        name = "global",
        args = { .Uint, .String, .Uint    }
      },
      Event{
        name = "global_remove",
        args = { .Uint    }
      },
    },
  },
  Interface{
    name = "callback",
    requests = {
    },
    events = {
      Event{
        name = "done",
        args = { .Uint    }
      },
    },
  },
  Interface{
    name = "compositor",
    requests = {
      Request{
        name = "create_surface",
        args = { .NewId    }
      },
      Request{
        name = "create_region",
        args = { .NewId    }
      },
    },
    events = {
    },
  },
  Interface{
    name = "shm_pool",
    requests = {
      Request{
        name = "create_buffer",
        args = { .NewId, .Int, .Int, .Int, .Int, .Uint    }
      },
      Request{
        name = "destroy",
        args = {     }
      },
      Request{
        name = "resize",
        args = { .Int    }
      },
    },
    events = {
    },
  },
  Interface{
    name = "shm",
    requests = {
      Request{
        name = "create_pool",
        args = { .NewId, .Fd, .Int    }
      },
      Request{
        name = "release",
        args = {     }
      },
    },
    events = {
      Event{
        name = "format",
        args = { .Uint    }
      },
    },
  },
  Interface{
    name = "buffer",
    requests = {
      Request{
        name = "destroy",
        args = {     }
      },
    },
    events = {
      Event{
        name = "release",
        args = {     }
      },
    },
  },
  Interface{
    name = "data_offer",
    requests = {
      Request{
        name = "accept",
        args = { .Uint, .String    }
      },
      Request{
        name = "receive",
        args = { .String, .Fd    }
      },
      Request{
        name = "destroy",
        args = {     }
      },
      Request{
        name = "finish",
        args = {     }
      },
      Request{
        name = "set_actions",
        args = { .Uint, .Uint    }
      },
    },
    events = {
      Event{
        name = "offer",
        args = { .String    }
      },
      Event{
        name = "source_actions",
        args = { .Uint    }
      },
      Event{
        name = "action",
        args = { .Uint    }
      },
    },
  },
  Interface{
    name = "data_source",
    requests = {
      Request{
        name = "offer",
        args = { .String    }
      },
      Request{
        name = "destroy",
        args = {     }
      },
      Request{
        name = "set_actions",
        args = { .Uint    }
      },
    },
    events = {
      Event{
        name = "target",
        args = { .String    }
      },
      Event{
        name = "send",
        args = { .String, .Fd    }
      },
      Event{
        name = "cancelled",
        args = {     }
      },
      Event{
        name = "dnd_drop_performed",
        args = {     }
      },
      Event{
        name = "dnd_finished",
        args = {     }
      },
      Event{
        name = "action",
        args = { .Uint    }
      },
    },
  },
  Interface{
    name = "data_device",
    requests = {
      Request{
        name = "start_drag",
        args = { .Object, .Object, .Object, .Uint    }
      },
      Request{
        name = "set_selection",
        args = { .Object, .Uint    }
      },
      Request{
        name = "release",
        args = {     }
      },
    },
    events = {
      Event{
        name = "data_offer",
        args = { .NewId    }
      },
      Event{
        name = "enter",
        args = { .Uint, .Object, .Fixed, .Fixed, .Object    }
      },
      Event{
        name = "leave",
        args = {     }
      },
      Event{
        name = "motion",
        args = { .Uint, .Fixed, .Fixed    }
      },
      Event{
        name = "drop",
        args = {     }
      },
      Event{
        name = "selection",
        args = { .Object    }
      },
    },
  },
  Interface{
    name = "data_device_manager",
    requests = {
      Request{
        name = "create_data_source",
        args = { .NewId    }
      },
      Request{
        name = "get_data_device",
        args = { .NewId, .Object    }
      },
    },
    events = {
    },
  },
  Interface{
    name = "shell",
    requests = {
      Request{
        name = "get_shell_surface",
        args = { .NewId, .Object    }
      },
    },
    events = {
    },
  },
  Interface{
    name = "shell_surface",
    requests = {
      Request{
        name = "pong",
        args = { .Uint    }
      },
      Request{
        name = "move",
        args = { .Object, .Uint    }
      },
      Request{
        name = "resize",
        args = { .Object, .Uint, .Uint    }
      },
      Request{
        name = "set_toplevel",
        args = {     }
      },
      Request{
        name = "set_transient",
        args = { .Object, .Int, .Int, .Uint    }
      },
      Request{
        name = "set_fullscreen",
        args = { .Uint, .Uint, .Object    }
      },
      Request{
        name = "set_popup",
        args = { .Object, .Uint, .Object, .Int, .Int, .Uint    }
      },
      Request{
        name = "set_maximized",
        args = { .Object    }
      },
      Request{
        name = "set_title",
        args = { .String    }
      },
      Request{
        name = "set_class",
        args = { .String    }
      },
    },
    events = {
      Event{
        name = "ping",
        args = { .Uint    }
      },
      Event{
        name = "configure",
        args = { .Uint, .Int, .Int    }
      },
      Event{
        name = "popup_done",
        args = {     }
      },
    },
  },
  Interface{
    name = "surface",
    requests = {
      Request{
        name = "destroy",
        args = {     }
      },
      Request{
        name = "attach",
        args = { .Object, .Int, .Int    }
      },
      Request{
        name = "damage",
        args = { .Int, .Int, .Int, .Int    }
      },
      Request{
        name = "frame",
        args = { .NewId    }
      },
      Request{
        name = "set_opaque_region",
        args = { .Object    }
      },
      Request{
        name = "set_input_region",
        args = { .Object    }
      },
      Request{
        name = "commit",
        args = {     }
      },
      Request{
        name = "set_buffer_transform",
        args = { .Int    }
      },
      Request{
        name = "set_buffer_scale",
        args = { .Int    }
      },
      Request{
        name = "damage_buffer",
        args = { .Int, .Int, .Int, .Int    }
      },
      Request{
        name = "offset",
        args = { .Int, .Int    }
      },
    },
    events = {
      Event{
        name = "enter",
        args = { .Object    }
      },
      Event{
        name = "leave",
        args = { .Object    }
      },
      Event{
        name = "preferred_buffer_scale",
        args = { .Int    }
      },
      Event{
        name = "preferred_buffer_transform",
        args = { .Uint    }
      },
    },
  },
  Interface{
    name = "seat",
    requests = {
      Request{
        name = "get_pointer",
        args = { .NewId    }
      },
      Request{
        name = "get_keyboard",
        args = { .NewId    }
      },
      Request{
        name = "get_touch",
        args = { .NewId    }
      },
      Request{
        name = "release",
        args = {     }
      },
    },
    events = {
      Event{
        name = "capabilities",
        args = { .Uint    }
      },
      Event{
        name = "name",
        args = { .String    }
      },
    },
  },
  Interface{
    name = "pointer",
    requests = {
      Request{
        name = "set_cursor",
        args = { .Uint, .Object, .Int, .Int    }
      },
      Request{
        name = "release",
        args = {     }
      },
    },
    events = {
      Event{
        name = "enter",
        args = { .Uint, .Object, .Fixed, .Fixed    }
      },
      Event{
        name = "leave",
        args = { .Uint, .Object    }
      },
      Event{
        name = "motion",
        args = { .Uint, .Fixed, .Fixed    }
      },
      Event{
        name = "button",
        args = { .Uint, .Uint, .Uint, .Uint    }
      },
      Event{
        name = "axis",
        args = { .Uint, .Uint, .Fixed    }
      },
      Event{
        name = "frame",
        args = {     }
      },
      Event{
        name = "axis_source",
        args = { .Uint    }
      },
      Event{
        name = "axis_stop",
        args = { .Uint, .Uint    }
      },
      Event{
        name = "axis_discrete",
        args = { .Uint, .Int    }
      },
      Event{
        name = "axis_value120",
        args = { .Uint, .Int    }
      },
      Event{
        name = "axis_relative_direction",
        args = { .Uint, .Uint    }
      },
    },
  },
  Interface{
    name = "keyboard",
    requests = {
      Request{
        name = "release",
        args = {     }
      },
    },
    events = {
      Event{
        name = "keymap",
        args = { .Uint, .Fd, .Uint    }
      },
      Event{
        name = "enter",
        args = { .Uint, .Object, .Array    }
      },
      Event{
        name = "leave",
        args = { .Uint, .Object    }
      },
      Event{
        name = "key",
        args = { .Uint, .Uint, .Uint, .Uint    }
      },
      Event{
        name = "modifiers",
        args = { .Uint, .Uint, .Uint, .Uint, .Uint    }
      },
      Event{
        name = "repeat_info",
        args = { .Int, .Int    }
      },
    },
  },
  Interface{
    name = "touch",
    requests = {
      Request{
        name = "release",
        args = {     }
      },
    },
    events = {
      Event{
        name = "down",
        args = { .Uint, .Uint, .Object, .Int, .Fixed, .Fixed    }
      },
      Event{
        name = "up",
        args = { .Uint, .Uint, .Int    }
      },
      Event{
        name = "motion",
        args = { .Uint, .Int, .Fixed, .Fixed    }
      },
      Event{
        name = "frame",
        args = {     }
      },
      Event{
        name = "cancel",
        args = {     }
      },
      Event{
        name = "shape",
        args = { .Int, .Fixed, .Fixed    }
      },
      Event{
        name = "orientation",
        args = { .Int, .Fixed    }
      },
    },
  },
  Interface{
    name = "output",
    requests = {
      Request{
        name = "release",
        args = {     }
      },
    },
    events = {
      Event{
        name = "geometry",
        args = { .Int, .Int, .Int, .Int, .Int, .String, .String, .Int    }
      },
      Event{
        name = "mode",
        args = { .Uint, .Int, .Int, .Int    }
      },
      Event{
        name = "done",
        args = {     }
      },
      Event{
        name = "scale",
        args = { .Int    }
      },
      Event{
        name = "name",
        args = { .String    }
      },
      Event{
        name = "description",
        args = { .String    }
      },
    },
  },
  Interface{
    name = "region",
    requests = {
      Request{
        name = "destroy",
        args = {     }
      },
      Request{
        name = "add",
        args = { .Int, .Int, .Int, .Int    }
      },
      Request{
        name = "subtract",
        args = { .Int, .Int, .Int, .Int    }
      },
    },
    events = {
    },
  },
  Interface{
    name = "subcompositor",
    requests = {
      Request{
        name = "destroy",
        args = {     }
      },
      Request{
        name = "get_subsurface",
        args = { .NewId, .Object, .Object    }
      },
    },
    events = {
    },
  },
  Interface{
    name = "subsurface",
    requests = {
      Request{
        name = "destroy",
        args = {     }
      },
      Request{
        name = "set_position",
        args = { .Int, .Int    }
      },
      Request{
        name = "place_above",
        args = { .Object    }
      },
      Request{
        name = "place_below",
        args = { .Object    }
      },
      Request{
        name = "set_sync",
        args = {     }
      },
      Request{
        name = "set_desync",
        args = {     }
      },
    },
    events = {
    },
  },
  Interface{
    name = "fixes",
    requests = {
      Request{
        name = "destroy",
        args = {     }
      },
      Request{
        name = "destroy_registry",
        args = { .Object    }
      },
    },
    events = {
    },
  },
}
