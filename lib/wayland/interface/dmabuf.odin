package interface

DMA_INTERFACES := [?]Interface {
  Interface {
    name = "zwp_linux_dmabuf_v1",
    requests = {
      Request{name = "destroy", arguments = {}},
      Request{name = "create_params", arguments = {.BoundNewId}},
      Request{name = "get_default_feedback", arguments = {.BoundNewId}},
      Request{name = "get_surface_feedback", arguments = {.BoundNewId, .Object}},
    },
    events = {
      Event{name = "format", arguments = {.Uint}},
      Event{name = "modifier", arguments = {.Uint, .Uint, .Uint}},
    },
  },
  Interface {
    name = "zwp_linux_buffer_params_v1",
    requests = {
      Request{name = "destroy", arguments = {}},
      Request{name = "add", arguments = {.Fd, .Uint, .Uint, .Uint, .Uint, .Uint}},
      Request{name = "create", arguments = {.Int, .Int, .Uint, .Uint}},
      Request{name = "create_immed", arguments = {.BoundNewId, .Int, .Int, .Uint, .Uint}},
    },
    events = {
      Event{name = "created", arguments = {.BoundNewId}},
      Event{name = "failed", arguments = {}},
    },
  },
  Interface {
    name = "zwp_linux_dmabuf_feedback_v1",
    requests = {Request{name = "destroy", arguments = {}}},
    events = {
      Event{name = "done", arguments = {}},
      Event{name = "format_table", arguments = {.Fd, .Uint}},
      Event{name = "main_device", arguments = {.Array}},
      Event{name = "tranche_done", arguments = {}},
      Event{name = "tranche_target_device", arguments = {.Array}},
      Event{name = "tranche_formats", arguments = {.Array}},
      Event{name = "tranche_flags", arguments = {.Uint}},
    },
  },
}
