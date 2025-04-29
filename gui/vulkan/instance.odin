package vulk

import "./../collection"

Instance :: struct {
  geometry_id: u32,
  model:       InstanceModel,
  id:    u32,
}

instance_init :: proc(ctx: ^Vulkan_Context, geometry_id: u32, model: InstanceModel, color: Color) -> (id: u32, err: Error) {
  instance: Instance
  instance.geometry_id = geometry_id
  instance.model = model
  instance.id = geometry_add_instance(ctx, geometry_id, model, color) or_return

  collection.vec_append(&ctx.instances, instance)

  return id, nil
}

instance_update :: proc(ctx: ^Vulkan_Context, instance_id: u32, model: InstanceModel, color: Color) -> Error {
  instance := &ctx.instances.data[instance_id]
  geometry_update_instance(ctx, instance.geometry_id, instance.id, model, color) or_return

  return nil
}

