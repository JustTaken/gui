package wayland

import "base:intrinsics"
import "core:mem"
import "core:sys/posix"
import "core:log"

import "lib:collection/vector"
import "lib:error"
import "lib:wayland/interface"
import "lib:xkb"

@private Callback :: proc(_: ^Wayland_Context, _: u32, _: []interface.Argument) -> error.Error
@private
CallbackConfig :: struct {
  name:     string,
  function: Callback,
}

@private
new_callback :: proc(name: string, callback: Callback) -> CallbackConfig {
  return CallbackConfig{name = name, function = callback}
}

@private
keyboard_keymap_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  size := uint(arguments[2].(interface.Uint))

  data := ([^]u8)(posix.mmap(nil, size, {.READ}, {.PRIVATE}, posix.FD(arguments[1].(interface.Fd)), 0))[0:size]
  defer posix.munmap(raw_data(data), size)

  if data == nil {
    return .OutOfMemory
  }

  ctx.keymap = xkb.keymap_from_bytes(data, ctx.allocator, ctx.tmp_allocator) or_return

  return nil
}

@private
keyboard_enter_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}
@private
keyboard_leave_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}
@private
keyboard_key_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  xkb.register_code(&ctx.keymap, u32(arguments[2].(interface.Uint)), u32(arguments[3].(interface.Uint))) or_return

  return nil
}
@private
keyboard_modifiers_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  xkb.set_modifiers(&ctx.keymap, u32(arguments[1].(interface.Uint)))

  return nil
}
@private
keyboard_repeat_info_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}

@private
pointer_enter_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}
@private
pointer_leave_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}
@private
pointer_motion_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}
@private
pointer_button_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}
@private
pointer_axis_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}
@private
pointer_frame_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}
@private
pointer_axis_source_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}
@private
pointer_axis_stop_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}
@private
pointer_axis_discrete_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}
@private
pointer_axis_create_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}
@private
pointer_axis_value120_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}
@private
pointer_axis_relative_direction_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}

@private
seat_name_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
}

@private
dma_modifier_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}
@private
dma_format_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}
@private
configure_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  write(ctx, {arguments[0]}, id, ctx.opcodes.ack_configure)

  return nil
}

@private
ping_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  write(ctx, {arguments[0]}, ctx.ids.xdg_wm_base, ctx.opcodes.pong)

  return nil
}

@private
toplevel_configure_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  width := u32(arguments[0].(interface.Int))
  height := u32(arguments[1].(interface.Int))

  if width == 0 || height == 0 do return nil
  if width == ctx.width && height == ctx.height do return nil

  resize(ctx, width, height) or_return

  return nil
}

@private
toplevel_close_callback :: proc(ctx: ^Wayland_Context, id: u32, arugments: []interface.Argument) -> error.Error {
  ctx.running = false

  return nil
}

@private
toplevel_configure_bounds_callback :: proc(ctx: ^Wayland_Context, id: u32, arugments: []interface.Argument) -> error.Error {
  return nil
  
}

@private
toplevel_wm_capabilities_callback :: proc(ctx: ^Wayland_Context, id: u32, arugments: []interface.Argument) -> error.Error {
  return nil
  
}

@private
buffer_release_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  ctx.buffers.data[id - ctx.ids.buffer_base].released = true
  return nil
}

@private
enter_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}
@private
leave_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}
@private
preferred_buffer_scale_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}
@private
preferred_buffer_transform_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}

@private
dma_tranche_flags_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}
@private
dma_format_table_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  fd := posix.FD(arguments[0].(interface.Fd))
  size := u32(arguments[1].(interface.Uint))

  buf := ([^]u8)(posix.mmap(nil, uint(size), {.READ}, {.PRIVATE}, fd, 0))[0:size]
  defer posix.munmap(raw_data(buf), uint(size))

  if buf == nil do return .OutOfMemory

  format_size: u32 = size_of(u32)
  modifier_size: u32 = size_of(u64)
  tuple_size := u32(mem.align_formula(int(format_size + modifier_size), int(modifier_size)))

  count := size / tuple_size
  for i in 0 ..< count {
    offset := u32(i) * tuple_size
    modifier := vector.one(&ctx.modifiers) or_return

    modifier.format = intrinsics.unaligned_load((^u32)(raw_data(buf[offset:][0:format_size])))
    modifier.modifier = intrinsics.unaligned_load((^u64)(raw_data(buf[offset + modifier_size:][0:modifier_size])))
  }

  return nil
}

@private
dma_main_device_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  ctx.dma_main_device = intrinsics.unaligned_load((^u64)(raw_data(arguments[0].(interface.Array))))

  return nil
}

@private
dma_done_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  write(ctx, {}, id, ctx.opcodes.dma_feedback_destroy)

  return nil
}

@private
dma_tranche_target_device_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}

@private
dma_tranche_formats_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  array := arguments[0].(interface.Array)
  indices := ([^]u16)(raw_data(array))[0:len(array) / 2]

  l: u32 = 0
  modifiers := ctx.modifiers
  ctx.modifiers.len = 0

  for i in indices {
    vector.append(&ctx.modifiers, modifiers.data[i])
  }

  return nil
}

@private
dma_tranche_done_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}

@private
param_created_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}

@private
param_failed_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return .DmaBufFailed
}

@private
delete_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
  
}

@private
error_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  log.error(string(arguments[2].(interface.String)))

  return .ErrorEvent
}

@private
global_remove_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  return nil
}

@private
global_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  ok: bool
  str := arguments[1].(interface.String)
  version := arguments[2].(interface.Uint)
  interface_name := string(str[0:len(str) - 1])

  switch interface_name {
  case "xdg_wm_base":
    ctx.ids.xdg_wm_base = get_id(ctx, interface_name, {new_callback("ping", ping_callback)}, interface.XDG_INTERFACES[:]) or_return
    ctx.opcodes.pong = get_request_opcode(ctx, "pong", ctx.ids.xdg_wm_base) or_return
    ctx.opcodes.get_xdg_surface = get_request_opcode(ctx, "get_xdg_surface", ctx.ids.xdg_wm_base) or_return

    write(ctx, { arguments[0], interface.UnBoundNewId { id = interface.BoundNewId(ctx.ids.xdg_wm_base), interface = str, version = version, }, }, ctx.ids.registry, ctx.opcodes.registry_bind) or_return
    xdg_surface_create(ctx)
  case "wl_compositor":
    ctx.ids.compositor = get_id(ctx, interface_name, {}, interface.WAYLAND_INTERFACES[:]) or_return
    ctx.opcodes.create_surface = get_request_opcode(ctx, "create_surface", ctx.ids.compositor) or_return

    write(ctx, { arguments[0], interface.UnBoundNewId { id = interface.BoundNewId(ctx.ids.compositor), interface = str, version = version, }, }, ctx.ids.registry, ctx.opcodes.registry_bind) or_return
    surface_create(ctx)
  case "wl_seat":
    ctx.ids.seat = get_id(ctx, interface_name, {new_callback("capabilities", seat_capabilities_callback), new_callback("name", seat_name_callback)}, interface.WAYLAND_INTERFACES[:]) or_return
    ctx.opcodes.get_pointer = get_request_opcode(ctx, "get_pointer", ctx.ids.seat) or_return
    ctx.opcodes.get_keyboard = get_request_opcode(ctx, "get_keyboard", ctx.ids.seat) or_return

    write(ctx, { arguments[0], interface.UnBoundNewId{id = interface.BoundNewId(ctx.ids.seat), interface = str, version = version}, }, ctx.ids.registry, ctx.opcodes.registry_bind) or_return
  case "zwp_linux_dmabuf_v1":
    ctx.ids.dma = get_id(ctx, interface_name, { new_callback("format", dma_format_callback), new_callback("modifier", dma_modifier_callback), }, interface.DMA_INTERFACES[:]) or_return
    ctx.opcodes.dma_destroy = get_request_opcode(ctx, "destroy", ctx.ids.dma) or_return
    ctx.opcodes.dma_create_param = get_request_opcode(ctx, "create_params", ctx.ids.dma) or_return
    ctx.opcodes.dma_surface_feedback = get_request_opcode(ctx, "get_surface_feedback", ctx.ids.dma) or_return

    write(ctx, { arguments[0], interface.UnBoundNewId{id = interface.BoundNewId(ctx.ids.dma), interface = str, version = version}, }, ctx.ids.registry, ctx.opcodes.registry_bind) or_return
  }

  return nil
}

@private
seat_capabilities_callback :: proc(ctx: ^Wayland_Context, id: u32, arguments: []interface.Argument) -> error.Error {
  Seat_Capability :: enum {
    Pointer  = 0,
    Keyboard = 1,
    Touch    = 2,
  }

  Seat_Capabilities :: bit_set[Seat_Capability;u32]

  capabilities := transmute(Seat_Capabilities)u32(arguments[0].(interface.Uint))

  if .Pointer in capabilities {
    ctx.ids.pointer = get_id(ctx, "wl_pointer", { new_callback("leave", pointer_leave_callback), new_callback("enter", pointer_enter_callback), new_callback("motion", pointer_motion_callback), new_callback("button", pointer_button_callback), new_callback("frame", pointer_frame_callback), new_callback("axis", pointer_axis_callback), new_callback("axis_source", pointer_axis_source_callback), new_callback("axis_stop", pointer_axis_stop_callback), new_callback("axis_discrete", pointer_axis_discrete_callback), new_callback("axis_value120", pointer_axis_value120_callback), new_callback("axis_relative_direction", pointer_axis_relative_direction_callback), }, interface.WAYLAND_INTERFACES[:]) or_return
    write(ctx, {interface.BoundNewId(ctx.ids.pointer)}, ctx.ids.seat, ctx.opcodes.get_pointer) or_return
  }

  if .Keyboard in capabilities {
    ctx.ids.keyboard = get_id(ctx, "wl_keyboard", { new_callback("leave", keyboard_leave_callback), new_callback("enter", keyboard_enter_callback), new_callback("key", keyboard_key_callback), new_callback("keymap", keyboard_keymap_callback), new_callback("modifiers", keyboard_modifiers_callback), new_callback("repeat_info", keyboard_repeat_info_callback), }, interface.WAYLAND_INTERFACES[:]) or_return
    write(ctx, {interface.BoundNewId(ctx.ids.keyboard)}, ctx.ids.seat, ctx.opcodes.get_keyboard) or_return
  }

  return nil
}
