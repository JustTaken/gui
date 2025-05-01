package vulk

import "./../collection"

// instance_create :: proc(ctx: ^Vulkan_Context, geometry_id: u32, model: InstanceModel, color: Color) -> (id: u32, err: Error) {
//   instance: Instance
//   instance.geometry_id = geometry_id
//   instance.model = model
//   instance.id = geometry_add_instance(ctx, geometry_id, model, color) or_return

//   collection.vec_append(&ctx.instances, instance)

//   return id, nil
// }

// instance_update :: proc(ctx: ^Vulkan_Context, instance_id: u32, model: Maybe(InstanceModel), color: Maybe(Color)) -> Error {
//   geometry_update_instance(ctx, instance.geometry_id, instance.id, model, color) or_return

//   return nil
// }

