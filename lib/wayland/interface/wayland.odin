package interface

WAYLAND_INTERFACES := [?]Interface {
  Interface {
    name = "wl_display",
    requests = {
      Request{name = "sync", arguments = {.BoundNewId}},
      Request{name = "get_registry", arguments = {.BoundNewId}},
    },
    events = {
      Event{name = "error", arguments = {.Object, .Uint, .String}},
      Event{name = "delete_id", arguments = {.Uint}},
    },
  },
  Interface {
    name = "wl_registry",
    requests = {Request{name = "bind", arguments = {.Uint, .UnBoundNewId}}},
    events = {
      Event{name = "global", arguments = {.Uint, .String, .Uint}},
      Event{name = "global_remove", arguments = {.Uint}},
    },
  },
  Interface {
    name = "wl_callback",
    requests = {},
    events = {Event{name = "done", arguments = {.Uint}}},
  },
  Interface {
    name = "wl_compositor",
    requests = {
      Request{name = "create_surface", arguments = {.BoundNewId}},
      Request{name = "create_region", arguments = {.BoundNewId}},
    },
    events = {},
  },
  Interface {
    name = "wl_shm_pool",
    requests = {
      Request {
        name = "create_buffer",
        arguments = {.BoundNewId, .Int, .Int, .Int, .Int, .Uint},
      },
      Request{name = "destroy", arguments = {}},
      Request{name = "resize", arguments = {.Int}},
    },
    events = {},
  },
  Interface {
    name = "wl_shm",
    requests = {
      Request{name = "create_pool", arguments = {.BoundNewId, .Fd, .Int}},
      Request{name = "release", arguments = {}},
    },
    events = {Event{name = "format", arguments = {.Uint}}},
  },
  Interface {
    name = "wl_buffer",
    requests = {Request{name = "destroy", arguments = {}}},
    events = {Event{name = "release", arguments = {}}},
  },
  Interface {
    name = "wl_data_offer",
    requests = {
      Request{name = "accept", arguments = {.Uint, .String}},
      Request{name = "receive", arguments = {.String, .Fd}},
      Request{name = "destroy", arguments = {}},
      Request{name = "finish", arguments = {}},
      Request{name = "set_actions", arguments = {.Uint, .Uint}},
    },
    events = {
      Event{name = "offer", arguments = {.String}},
      Event{name = "source_actions", arguments = {.Uint}},
      Event{name = "action", arguments = {.Uint}},
    },
  },
  Interface {
    name = "wl_data_source",
    requests = {
      Request{name = "offer", arguments = {.String}},
      Request{name = "destroy", arguments = {}},
      Request{name = "set_actions", arguments = {.Uint}},
    },
    events = {
      Event{name = "target", arguments = {.String}},
      Event{name = "send", arguments = {.String, .Fd}},
      Event{name = "cancelled", arguments = {}},
      Event{name = "dnd_drop_performed", arguments = {}},
      Event{name = "dnd_finished", arguments = {}},
      Event{name = "action", arguments = {.Uint}},
    },
  },
  Interface {
    name = "wl_data_device",
    requests = {
      Request{name = "start_drag", arguments = {.Object, .Object, .Object, .Uint}},
      Request{name = "set_selection", arguments = {.Object, .Uint}},
      Request{name = "release", arguments = {}},
    },
    events = {
      Event{name = "data_offer", arguments = {.BoundNewId}},
      Event{name = "enter", arguments = {.Uint, .Object, .Fixed, .Fixed, .Object}},
      Event{name = "leave", arguments = {}},
      Event{name = "motion", arguments = {.Uint, .Fixed, .Fixed}},
      Event{name = "drop", arguments = {}},
      Event{name = "selection", arguments = {.Object}},
    },
  },
  Interface {
    name = "wl_data_device_manager",
    requests = {
      Request{name = "create_data_source", arguments = {.BoundNewId}},
      Request{name = "get_data_device", arguments = {.BoundNewId, .Object}},
    },
    events = {},
  },
  Interface {
    name = "wl_shell",
    requests = {Request{name = "get_shell_surface", arguments = {.BoundNewId, .Object}}},
    events = {},
  },
  Interface {
    name = "wl_shell_surface",
    requests = {
      Request{name = "pong", arguments = {.Uint}},
      Request{name = "move", arguments = {.Object, .Uint}},
      Request{name = "resize", arguments = {.Object, .Uint, .Uint}},
      Request{name = "set_toplevel", arguments = {}},
      Request{name = "set_transient", arguments = {.Object, .Int, .Int, .Uint}},
      Request{name = "set_fullscreen", arguments = {.Uint, .Uint, .Object}},
      Request{name = "set_popup", arguments = {.Object, .Uint, .Object, .Int, .Int, .Uint}},
      Request{name = "set_maximized", arguments = {.Object}},
      Request{name = "set_title", arguments = {.String}},
      Request{name = "set_class", arguments = {.String}},
    },
    events = {
      Event{name = "ping", arguments = {.Uint}},
      Event{name = "configure", arguments = {.Uint, .Int, .Int}},
      Event{name = "popup_done", arguments = {}},
    },
  },
  Interface {
    name = "wl_surface",
    requests = {
      Request{name = "destroy", arguments = {}},
      Request{name = "attach", arguments = {.Object, .Int, .Int}},
      Request{name = "damage", arguments = {.Int, .Int, .Int, .Int}},
      Request{name = "frame", arguments = {.BoundNewId}},
      Request{name = "set_opaque_region", arguments = {.Object}},
      Request{name = "set_input_region", arguments = {.Object}},
      Request{name = "commit", arguments = {}},
      Request{name = "set_buffer_transform", arguments = {.Int}},
      Request{name = "set_buffer_scale", arguments = {.Int}},
      Request{name = "damage_buffer", arguments = {.Int, .Int, .Int, .Int}},
      Request{name = "offset", arguments = {.Int, .Int}},
    },
    events = {
      Event{name = "enter", arguments = {.Object}},
      Event{name = "leave", arguments = {.Object}},
      Event{name = "preferred_buffer_scale", arguments = {.Int}},
      Event{name = "preferred_buffer_transform", arguments = {.Uint}},
    },
  },
  Interface {
    name = "wl_seat",
    requests = {
      Request{name = "get_pointer", arguments = {.BoundNewId}},
      Request{name = "get_keyboard", arguments = {.BoundNewId}},
      Request{name = "get_touch", arguments = {.BoundNewId}},
      Request{name = "release", arguments = {}},
    },
    events = {
      Event{name = "capabilities", arguments = {.Uint}},
      Event{name = "name", arguments = {.String}},
    },
  },
  Interface {
    name = "wl_pointer",
    requests = {
      Request{name = "set_cursor", arguments = {.Uint, .Object, .Int, .Int}},
      Request{name = "release", arguments = {}},
    },
    events = {
      Event{name = "enter", arguments = {.Uint, .Object, .Fixed, .Fixed}},
      Event{name = "leave", arguments = {.Uint, .Object}},
      Event{name = "motion", arguments = {.Uint, .Fixed, .Fixed}},
      Event{name = "button", arguments = {.Uint, .Uint, .Uint, .Uint}},
      Event{name = "axis", arguments = {.Uint, .Uint, .Fixed}},
      Event{name = "frame", arguments = {}},
      Event{name = "axis_source", arguments = {.Uint}},
      Event{name = "axis_stop", arguments = {.Uint, .Uint}},
      Event{name = "axis_discrete", arguments = {.Uint, .Int}},
      Event{name = "axis_value120", arguments = {.Uint, .Int}},
      Event{name = "axis_relative_direction", arguments = {.Uint, .Uint}},
    },
  },
  Interface {
    name = "wl_keyboard",
    requests = {Request{name = "release", arguments = {}}},
    events = {
      Event{name = "keymap", arguments = {.Uint, .Fd, .Uint}},
      Event{name = "enter", arguments = {.Uint, .Object, .Array}},
      Event{name = "leave", arguments = {.Uint, .Object}},
      Event{name = "key", arguments = {.Uint, .Uint, .Uint, .Uint}},
      Event{name = "modifiers", arguments = {.Uint, .Uint, .Uint, .Uint, .Uint}},
      Event{name = "repeat_info", arguments = {.Int, .Int}},
    },
  },
  Interface {
    name = "wl_touch",
    requests = {Request{name = "release", arguments = {}}},
    events = {
      Event{name = "down", arguments = {.Uint, .Uint, .Object, .Int, .Fixed, .Fixed}},
      Event{name = "up", arguments = {.Uint, .Uint, .Int}},
      Event{name = "motion", arguments = {.Uint, .Int, .Fixed, .Fixed}},
      Event{name = "frame", arguments = {}},
      Event{name = "cancel", arguments = {}},
      Event{name = "shape", arguments = {.Int, .Fixed, .Fixed}},
      Event{name = "orientation", arguments = {.Int, .Fixed}},
    },
  },
  Interface {
    name = "wl_output",
    requests = {Request{name = "release", arguments = {}}},
    events = {
      Event {
        name = "geometry",
        arguments = {.Int, .Int, .Int, .Int, .Int, .String, .String, .Int},
      },
      Event{name = "mode", arguments = {.Uint, .Int, .Int, .Int}},
      Event{name = "done", arguments = {}},
      Event{name = "scale", arguments = {.Int}},
      Event{name = "name", arguments = {.String}},
      Event{name = "description", arguments = {.String}},
    },
  },
  Interface {
    name = "wl_region",
    requests = {
      Request{name = "destroy", arguments = {}},
      Request{name = "add", arguments = {.Int, .Int, .Int, .Int}},
      Request{name = "subtract", arguments = {.Int, .Int, .Int, .Int}},
    },
    events = {},
  },
  Interface {
    name = "wl_subcompositor",
    requests = {
      Request{name = "destroy", arguments = {}},
      Request{name = "get_subsurface", arguments = {.BoundNewId, .Object, .Object}},
    },
    events = {},
  },
  Interface {
    name = "wl_subsurface",
    requests = {
      Request{name = "destroy", arguments = {}},
      Request{name = "set_position", arguments = {.Int, .Int}},
      Request{name = "place_above", arguments = {.Object}},
      Request{name = "place_below", arguments = {.Object}},
      Request{name = "set_sync", arguments = {}},
      Request{name = "set_desync", arguments = {}},
    },
    events = {},
  },
  Interface {
    name = "wl_fixes",
    requests = {
      Request{name = "destroy", arguments = {}},
      Request{name = "destroy_registry", arguments = {.Object}},
    },
    events = {},
  },
}
