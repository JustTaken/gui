package vulk

import "lib:error"
import vk "vendor:vulkan"

@(private)
create_instance :: proc(
  ctx: ^Vulkan_Context,
) -> (
  instance: vk.Instance,
  ok: error.Error,
) {
  layer_count: u32
  vk.EnumerateInstanceLayerProperties(&layer_count, nil)
  layers := make([]vk.LayerProperties, layer_count, ctx.tmp_allocator)
  vk.EnumerateInstanceLayerProperties(&layer_count, &layers[0])

  check :: proc(v: cstring, availables: []vk.LayerProperties) -> error.Error {
    for &available in availables do if v == cstring(&available.layerName[0]) do return nil

    return .LayerNotFound
  }

  app_info := vk.ApplicationInfo {
    sType              = .APPLICATION_INFO,
    pApplicationName   = "Hello Triangle",
    applicationVersion = vk.MAKE_VERSION(0, 0, 1),
    pEngineName        = "No Engine",
    engineVersion      = vk.MAKE_VERSION(0, 0, 1),
    apiVersion         = vk.MAKE_VERSION(1, 4, 3),
  }

  create_info := vk.InstanceCreateInfo {
    sType               = .INSTANCE_CREATE_INFO,
    pApplicationInfo    = &app_info,
    ppEnabledLayerNames = &VALIDATION_LAYERS[0],
    enabledLayerCount   = len(VALIDATION_LAYERS),
  }

  if vk.CreateInstance(&create_info, nil, &instance) != .SUCCESS do return instance, .CreateInstanceFailed

  vk.load_proc_addresses_instance(instance)

  return instance, nil
}
