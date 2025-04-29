package wayland

XDG_INTERFACES := [?]Interface {
  Interface {
    name = "xdg_wm_base",
    requests = {
      Request{name = "destroy", arguments = {}},
      Request{name = "create_positioner", arguments = {.BoundNewId}},
      Request{name = "get_xdg_surface", arguments = {.BoundNewId, .Object}},
      Request{name = "pong", arguments = {.Uint}},
    },
    events = {Event{name = "ping", arguments = {.Uint}}},
  },
  Interface {
    name = "xdg_positioner",
    requests = {
      Request{name = "destroy", arguments = {}},
      Request{name = "set_size", arguments = {.Int, .Int}},
      Request{name = "set_anchor_rect", arguments = {.Int, .Int, .Int, .Int}},
      Request{name = "set_anchor", arguments = {.Uint}},
      Request{name = "set_gravity", arguments = {.Uint}},
      Request{name = "set_constraint_adjustment", arguments = {.Uint}},
      Request{name = "set_offset", arguments = {.Int, .Int}},
      Request{name = "set_reactive", arguments = {}},
      Request{name = "set_parent_size", arguments = {.Int, .Int}},
      Request{name = "set_parent_configure", arguments = {.Uint}},
    },
    events = {},
  },
  Interface {
    name = "xdg_surface",
    requests = {
      Request{name = "destroy", arguments = {}},
      Request{name = "get_toplevel", arguments = {.BoundNewId}},
      Request{name = "get_popup", arguments = {.BoundNewId, .Object, .Object}},
      Request{name = "set_window_geometry", arguments = {.Int, .Int, .Int, .Int}},
      Request{name = "ack_configure", arguments = {.Uint}},
    },
    events = {Event{name = "configure", arguments = {.Uint}}},
  },
  Interface {
    name = "xdg_toplevel",
    requests = {
      Request{name = "destroy", arguments = {}},
      Request{name = "set_parent", arguments = {.Object}},
      Request{name = "set_title", arguments = {.String}},
      Request{name = "set_app_id", arguments = {.String}},
      Request{name = "show_window_menu", arguments = {.Object, .Uint, .Int, .Int}},
      Request{name = "move", arguments = {.Object, .Uint}},
      Request{name = "resize", arguments = {.Object, .Uint, .Uint}},
      Request{name = "set_max_size", arguments = {.Int, .Int}},
      Request{name = "set_min_size", arguments = {.Int, .Int}},
      Request{name = "set_maximized", arguments = {}},
      Request{name = "unset_maximized", arguments = {}},
      Request{name = "set_fullscreen", arguments = {.Object}},
      Request{name = "unset_fullscreen", arguments = {}},
      Request{name = "set_minimized", arguments = {}},
    },
    events = {
      Event{name = "configure", arguments = {.Int, .Int, .Array}},
      Event{name = "close", arguments = {}},
      Event{name = "configure_bounds", arguments = {.Int, .Int}},
      Event{name = "wm_capabilities", arguments = {.Array}},
    },
  },
  Interface {
    name = "xdg_popup",
    requests = {
      Request{name = "destroy", arguments = {}},
      Request{name = "grab", arguments = {.Object, .Uint}},
      Request{name = "reposition", arguments = {.Object, .Uint}},
    },
    events = {
      Event{name = "configure", arguments = {.Int, .Int, .Int, .Int}},
      Event{name = "popup_done", arguments = {}},
      Event{name = "repositioned", arguments = {.Uint}},
    },
  },
}
