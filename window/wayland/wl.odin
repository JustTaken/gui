package protocol
interfaces := [?]Interface{
  Interface{
    name = "wl_display",
    requests = {
      Request{
        name = "sync",
        arguments = { .NewId }
      },
      Request{
        name = "get_registry",
        arguments = { .NewId }
      },
      Request{
        name = "error",
        arguments = { .Object, .Uint, .String }
      },
      Request{
        name = "delete_id",
        arguments = { .Uint }
      },
    },
    events = {
    },
  },
  Interface{
    name = "wl_registry",
    requests = {
      Request{
        name = "bind",
        arguments = { .Uint, .NewId }
      },
      Request{
        name = "global",
        arguments = { .Uint, .String, .Uint }
      },
      Request{
        name = "global_remove",
        arguments = { .Uint }
      },
    },
    events = {
    },
  },
  Interface{
    name = "wl_callback",
    requests = {
      Request{
        name = "done",
        arguments = { .Uint }
      },
    },
    events = {
    },
  },
  Interface{
    name = "wl_compositor",
    requests = {
      Request{
        name = "create_surface",
        arguments = { .NewId }
      },
      Request{
        name = "create_region",
        arguments = { .NewId }
      },
    },
    events = {
    },
  },
  Interface{
    name = "wl_shm_pool",
    requests = {
      Request{
        name = "create_buffer",
        arguments = { .NewId, .Int, .Int, .Int, .Int, .Uint }
      },
      Request{
        name = "destroy",
        arguments = {  }
      },
      Request{
        name = "resize",
        arguments = { .Int }
      },
    },
    events = {
    },
  },
  Interface{
    name = "wl_shm",
    requests = {
      Request{
        name = "create_pool",
        arguments = { .NewId, .Fd, .Int }
      },
      Request{
        name = "format",
        arguments = { .Uint }
      },
      Request{
        name = "release",
        arguments = {  }
      },
    },
    events = {
    },
  },
  Interface{
    name = "wl_buffer",
    requests = {
      Request{
        name = "destroy",
        arguments = {  }
      },
      Request{
        name = "release",
        arguments = {  }
      },
    },
    events = {
    },
  },
  Interface{
    name = "wl_data_offer",
    requests = {
      Request{
        name = "accept",
        arguments = { .Uint, .String }
      },
      Request{
        name = "receive",
        arguments = { .String, .Fd }
      },
      Request{
        name = "destroy",
        arguments = {  }
      },
      Request{
        name = "offer",
        arguments = { .String }
      },
      Request{
        name = "finish",
        arguments = {  }
      },
      Request{
        name = "set_actions",
        arguments = { .Uint, .Uint }
      },
      Request{
        name = "source_actions",
        arguments = { .Uint }
      },
      Request{
        name = "action",
        arguments = { .Uint }
      },
    },
    events = {
    },
  },
  Interface{
    name = "wl_data_source",
    requests = {
      Request{
        name = "offer",
        arguments = { .String }
      },
      Request{
        name = "destroy",
        arguments = {  }
      },
      Request{
        name = "target",
        arguments = { .String }
      },
      Request{
        name = "send",
        arguments = { .String, .Fd }
      },
      Request{
        name = "cancelled",
        arguments = {  }
      },
      Request{
        name = "set_actions",
        arguments = { .Uint }
      },
      Request{
        name = "dnd_drop_performed",
        arguments = {  }
      },
      Request{
        name = "dnd_finished",
        arguments = {  }
      },
      Request{
        name = "action",
        arguments = { .Uint }
      },
    },
    events = {
    },
  },
  Interface{
    name = "wl_data_device",
    requests = {
      Request{
        name = "start_drag",
        arguments = { .Object, .Object, .Object, .Uint }
      },
      Request{
        name = "set_selection",
        arguments = { .Object, .Uint }
      },
      Request{
        name = "data_offer",
        arguments = { .NewId }
      },
      Request{
        name = "enter",
        arguments = { .Uint, .Object, .Fixed, .Fixed, .Object }
      },
      Request{
        name = "leave",
        arguments = {  }
      },
      Request{
        name = "motion",
        arguments = { .Uint, .Fixed, .Fixed }
      },
      Request{
        name = "drop",
        arguments = {  }
      },
      Request{
        name = "selection",
        arguments = { .Object }
      },
      Request{
        name = "release",
        arguments = {  }
      },
    },
    events = {
    },
  },
  Interface{
    name = "wl_data_device_manager",
    requests = {
      Request{
        name = "create_data_source",
        arguments = { .NewId }
      },
      Request{
        name = "get_data_device",
        arguments = { .NewId, .Object }
      },
    },
    events = {
    },
  },
  Interface{
    name = "wl_shell",
    requests = {
      Request{
        name = "get_shell_surface",
        arguments = { .NewId, .Object }
      },
    },
    events = {
    },
  },
  Interface{
    name = "wl_shell_surface",
    requests = {
      Request{
        name = "pong",
        arguments = { .Uint }
      },
      Request{
        name = "move",
        arguments = { .Object, .Uint }
      },
      Request{
        name = "resize",
        arguments = { .Object, .Uint, .Uint }
      },
      Request{
        name = "set_toplevel",
        arguments = {  }
      },
      Request{
        name = "set_transient",
        arguments = { .Object, .Int, .Int, .Uint }
      },
      Request{
        name = "set_fullscreen",
        arguments = { .Uint, .Uint, .Object }
      },
      Request{
        name = "set_popup",
        arguments = { .Object, .Uint, .Object, .Int, .Int, .Uint }
      },
      Request{
        name = "set_maximized",
        arguments = { .Object }
      },
      Request{
        name = "set_title",
        arguments = { .String }
      },
      Request{
        name = "set_class",
        arguments = { .String }
      },
      Request{
        name = "ping",
        arguments = { .Uint }
      },
      Request{
        name = "configure",
        arguments = { .Uint, .Int, .Int }
      },
      Request{
        name = "popup_done",
        arguments = {  }
      },
    },
    events = {
    },
  },
  Interface{
    name = "wl_surface",
    requests = {
      Request{
        name = "destroy",
        arguments = {  }
      },
      Request{
        name = "attach",
        arguments = { .Object, .Int, .Int }
      },
      Request{
        name = "damage",
        arguments = { .Int, .Int, .Int, .Int }
      },
      Request{
        name = "frame",
        arguments = { .NewId }
      },
      Request{
        name = "set_opaque_region",
        arguments = { .Object }
      },
      Request{
        name = "set_input_region",
        arguments = { .Object }
      },
      Request{
        name = "commit",
        arguments = {  }
      },
      Request{
        name = "enter",
        arguments = { .Object }
      },
      Request{
        name = "leave",
        arguments = { .Object }
      },
      Request{
        name = "set_buffer_transform",
        arguments = { .Int }
      },
      Request{
        name = "set_buffer_scale",
        arguments = { .Int }
      },
      Request{
        name = "damage_buffer",
        arguments = { .Int, .Int, .Int, .Int }
      },
      Request{
        name = "offset",
        arguments = { .Int, .Int }
      },
      Request{
        name = "preferred_buffer_scale",
        arguments = { .Int }
      },
      Request{
        name = "preferred_buffer_transform",
        arguments = { .Uint }
      },
    },
    events = {
    },
  },
  Interface{
    name = "wl_seat",
    requests = {
      Request{
        name = "capabilities",
        arguments = { .Uint }
      },
      Request{
        name = "get_pointer",
        arguments = { .NewId }
      },
      Request{
        name = "get_keyboard",
        arguments = { .NewId }
      },
      Request{
        name = "get_touch",
        arguments = { .NewId }
      },
      Request{
        name = "name",
        arguments = { .String }
      },
      Request{
        name = "release",
        arguments = {  }
      },
    },
    events = {
    },
  },
  Interface{
    name = "wl_pointer",
    requests = {
      Request{
        name = "set_cursor",
        arguments = { .Uint, .Object, .Int, .Int }
      },
      Request{
        name = "enter",
        arguments = { .Uint, .Object, .Fixed, .Fixed }
      },
      Request{
        name = "leave",
        arguments = { .Uint, .Object }
      },
      Request{
        name = "motion",
        arguments = { .Uint, .Fixed, .Fixed }
      },
      Request{
        name = "button",
        arguments = { .Uint, .Uint, .Uint, .Uint }
      },
      Request{
        name = "axis",
        arguments = { .Uint, .Uint, .Fixed }
      },
      Request{
        name = "release",
        arguments = {  }
      },
      Request{
        name = "frame",
        arguments = {  }
      },
      Request{
        name = "axis_source",
        arguments = { .Uint }
      },
      Request{
        name = "axis_stop",
        arguments = { .Uint, .Uint }
      },
      Request{
        name = "axis_discrete",
        arguments = { .Uint, .Int }
      },
      Request{
        name = "axis_value120",
        arguments = { .Uint, .Int }
      },
      Request{
        name = "axis_relative_direction",
        arguments = { .Uint, .Uint }
      },
    },
    events = {
    },
  },
  Interface{
    name = "wl_keyboard",
    requests = {
      Request{
        name = "keymap",
        arguments = { .Uint, .Fd, .Uint }
      },
      Request{
        name = "enter",
        arguments = { .Uint, .Object, .Array }
      },
      Request{
        name = "leave",
        arguments = { .Uint, .Object }
      },
      Request{
        name = "key",
        arguments = { .Uint, .Uint, .Uint, .Uint }
      },
      Request{
        name = "modifiers",
        arguments = { .Uint, .Uint, .Uint, .Uint, .Uint }
      },
      Request{
        name = "release",
        arguments = {  }
      },
      Request{
        name = "repeat_info",
        arguments = { .Int, .Int }
      },
    },
    events = {
    },
  },
  Interface{
    name = "wl_touch",
    requests = {
      Request{
        name = "down",
        arguments = { .Uint, .Uint, .Object, .Int, .Fixed, .Fixed }
      },
      Request{
        name = "up",
        arguments = { .Uint, .Uint, .Int }
      },
      Request{
        name = "motion",
        arguments = { .Uint, .Int, .Fixed, .Fixed }
      },
      Request{
        name = "frame",
        arguments = {  }
      },
      Request{
        name = "cancel",
        arguments = {  }
      },
      Request{
        name = "release",
        arguments = {  }
      },
      Request{
        name = "shape",
        arguments = { .Int, .Fixed, .Fixed }
      },
      Request{
        name = "orientation",
        arguments = { .Int, .Fixed }
      },
    },
    events = {
    },
  },
  Interface{
    name = "wl_output",
    requests = {
      Request{
        name = "geometry",
        arguments = { .Int, .Int, .Int, .Int, .Int, .String, .String, .Int }
      },
      Request{
        name = "mode",
        arguments = { .Uint, .Int, .Int, .Int }
      },
      Request{
        name = "done",
        arguments = {  }
      },
      Request{
        name = "scale",
        arguments = { .Int }
      },
      Request{
        name = "release",
        arguments = {  }
      },
      Request{
        name = "name",
        arguments = { .String }
      },
      Request{
        name = "description",
        arguments = { .String }
      },
    },
    events = {
    },
  },
  Interface{
    name = "wl_region",
    requests = {
      Request{
        name = "destroy",
        arguments = {  }
      },
      Request{
        name = "add",
        arguments = { .Int, .Int, .Int, .Int }
      },
      Request{
        name = "subtract",
        arguments = { .Int, .Int, .Int, .Int }
      },
    },
    events = {
    },
  },
  Interface{
    name = "wl_subcompositor",
    requests = {
      Request{
        name = "destroy",
        arguments = {  }
      },
      Request{
        name = "get_subsurface",
        arguments = { .NewId, .Object, .Object }
      },
    },
    events = {
    },
  },
  Interface{
    name = "wl_subsurface",
    requests = {
      Request{
        name = "destroy",
        arguments = {  }
      },
      Request{
        name = "set_position",
        arguments = { .Int, .Int }
      },
      Request{
        name = "place_above",
        arguments = { .Object }
      },
      Request{
        name = "place_below",
        arguments = { .Object }
      },
      Request{
        name = "set_sync",
        arguments = {  }
      },
      Request{
        name = "set_desync",
        arguments = {  }
      },
    },
    events = {
    },
  },
  Interface{
    name = "wl_fixes",
    requests = {
      Request{
        name = "destroy",
        arguments = {  }
      },
      Request{
        name = "destroy_registry",
        arguments = { .Object }
      },
    },
    events = {
    },
  },
}
