package vulk

import "./../collection"

Widget :: struct {
  geometry_id: u32,
  id:    u32,
  model:       InstanceModel,
  childs:      []Instance,
  childs_len:  u32,
}

widget_create :: proc(ctx: ^Vulkan_Context, geometry_id: u32, model: InstanceModel, color: Color, count: u32) -> (id: u32, ok: Error) {
  widget: Widget
  widget.model = model

  widget.geometry_id = geometry_id
  widget.childs = make([]Instance, count, ctx.allocator)
  widget.childs_len = 0
  widget.id = geometry_add_instance(ctx, geometry_id, widget.model, color) or_return

  id = ctx.widgets.len
  collection.vec_append(&ctx.widgets, widget)

  return id, nil
}

widget_add_child :: proc(ctx: ^Vulkan_Context, widget_id: u32, geometry_id: u32, model: InstanceModel, color: Color) -> (id: u32, err: Error) {
  widget := &ctx.widgets.data[widget_id]

  instance_model := relative_center(widget.model, model)
  id = geometry_add_instance(ctx, geometry_id, instance_model, color) or_return

  widget.childs[widget.childs_len].geometry_id = geometry_id
  widget.childs[widget.childs_len].model = model
  widget.childs[widget.childs_len].id = id

  id = widget.childs_len
  widget.childs_len += 1

  return id, nil
}

widget_update :: proc(ctx: ^Vulkan_Context, widget_id: u32, model: Maybe(InstanceModel), color: Maybe(Color)) -> Error {
  widget := &ctx.widgets.data[widget_id]
  geometry_update_instance(ctx, widget.geometry_id, widget.id, model, color) or_return

  if model != nil {
    widget.model = model.?
  }

  for i in 0 ..< widget.childs_len {
    instance := &widget.childs[i]
    instance_model := relative_center(widget.model, instance.model)

    geometry_update_instance(ctx, instance.geometry_id, instance.id, instance_model, nil) or_return
  }

  return nil
}

relative_top_left :: proc(parent_model: InstanceModel, model: InstanceModel) -> InstanceModel {
  relative := model

  relative[0, 3] += parent_model[0, 3] + (model[0, 0] - parent_model[0, 0])
  relative[1, 3] += parent_model[1, 3] - (model[1, 1] - parent_model[1, 1])
  relative[2, 3] += parent_model[2, 3]

  return relative
}

relative_center :: proc(parent_model: InstanceModel, model: InstanceModel) -> InstanceModel {
  return parent_model + model
}
