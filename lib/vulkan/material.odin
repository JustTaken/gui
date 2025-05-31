package vulk

import "lib:error"

import "lib:collection/vector"

Material :: [4]f32

material_create :: proc(
  ctx: ^Vulkan_Context,
  color: [4]f32,
) -> (
  index: u32,
  err: error.Error,
) {
  index = ctx.materials.len

  material := color
  vector.append(&ctx.materials, material) or_return

  materials := [?]Material{material}

  copy_data_to_buffer(
    Material,
    ctx,
    materials[:],
    &ctx.dynamic_set.descriptors.data[MATERIALS].buffer,
    index,
  ) or_return

  return index, nil
}
