package vulk

import "lib:collection/vector"
import "lib:error"
import vk "vendor:vulkan"


Queue_Kind :: enum {
  Transfer,
  Graphics,
}

Queue :: struct {
  handle:        vk.Queue,
  indice:        u32,
  command_pools: vector.Vector(Command_Pool),
}

@(private)
Device :: struct {
  handle:  vk.Device,
  indices: [Queue_Kind]u32,
  queues:  vector.Vector(Queue),
}

@(private)
PLANE_INDICES := [?]vk.ImageAspectFlag {
  .MEMORY_PLANE_0_EXT,
  .MEMORY_PLANE_1_EXT,
  .MEMORY_PLANE_2_EXT,
  .MEMORY_PLANE_3_EXT,
}

@(private)
get_drm_modifiers :: proc(
  ctx: ^Vulkan_Context,
) -> (
  modifiers: vector.Vector(vk.DrmFormatModifierPropertiesEXT),
  err: error.Error,
) {
  render_features: vk.FormatFeatureFlags = {
    .COLOR_ATTACHMENT,
    .COLOR_ATTACHMENT_BLEND,
  }

  texture_features: vk.FormatFeatureFlags = {
    .SAMPLED_IMAGE,
    .SAMPLED_IMAGE_FILTER_LINEAR,
  }

  modifier_properties_list := vk.DrmFormatModifierPropertiesListEXT {
    sType = .DRM_FORMAT_MODIFIER_PROPERTIES_LIST_EXT,
  }

  properties := vk.FormatProperties2 {
    sType = .FORMAT_PROPERTIES_2,
    pNext = &modifier_properties_list,
  }

  vk.GetPhysicalDeviceFormatProperties2(
    ctx.physical_device,
    ctx.format,
    &properties,
  )
  count := modifier_properties_list.drmFormatModifierCount

  modifiers = vector.new(
    vk.DrmFormatModifierPropertiesEXT,
    u32(count),
    ctx.allocator,
  ) or_return

  drmFormatModifierProperties := make(
    []vk.DrmFormatModifierPropertiesEXT,
    count,
    ctx.tmp_allocator,
  )
  modifier_properties_list.pDrmFormatModifierProperties =
  &drmFormatModifierProperties[0]

  vk.GetPhysicalDeviceFormatProperties2(
    ctx.physical_device,
    ctx.format,
    &properties,
  )

  image_modifier_info := vk.PhysicalDeviceImageDrmFormatModifierInfoEXT {
    sType       = .PHYSICAL_DEVICE_IMAGE_DRM_FORMAT_MODIFIER_INFO_EXT,
    sharingMode = .EXCLUSIVE,
  }

  external_image_info := vk.PhysicalDeviceExternalImageFormatInfo {
    sType      = .PHYSICAL_DEVICE_EXTERNAL_IMAGE_FORMAT_INFO,
    pNext      = &image_modifier_info,
    handleType = {.DMA_BUF_EXT},
  }

  image_info := vk.PhysicalDeviceImageFormatInfo2 {
    sType  = .PHYSICAL_DEVICE_IMAGE_FORMAT_INFO_2,
    pNext  = &external_image_info,
    format = ctx.format,
    type   = .D2,
    tiling = .DRM_FORMAT_MODIFIER_EXT,
  }

  external_image_properties := vk.ExternalImageFormatProperties {
    sType = .EXTERNAL_IMAGE_FORMAT_PROPERTIES,
  }

  image_properties := vk.ImageFormatProperties2 {
    sType = .IMAGE_FORMAT_PROPERTIES_2,
    pNext = &external_image_properties,
  }

  emp := &external_image_properties.externalMemoryProperties

  for i in 0 ..< count {
    modifier_properties :=
      modifier_properties_list.pDrmFormatModifierProperties[i]

    image_modifier_info.drmFormatModifier =
      modifier_properties.drmFormatModifier

    if modifier_properties.drmFormatModifierTilingFeatures < render_features do continue
    if modifier_properties.drmFormatModifierTilingFeatures < texture_features do continue

    image_info.usage = {.COLOR_ATTACHMENT}

    if vk.GetPhysicalDeviceImageFormatProperties2(ctx.physical_device, &image_info, &image_properties) != .SUCCESS do continue
    if emp.externalMemoryFeatures < {.IMPORTABLE, .EXPORTABLE} do continue

    image_info.usage = {.SAMPLED}

    if vk.GetPhysicalDeviceImageFormatProperties2(ctx.physical_device, &image_info, &image_properties) != .SUCCESS do continue
    if emp.externalMemoryFeatures < {.IMPORTABLE, .EXPORTABLE} do continue

    vector.append(&modifiers, modifier_properties) or_return
  }

  return modifiers, nil
}

@(private)
check_physical_device_ext_support :: proc(
  ctx: ^Vulkan_Context,
  physical_device: vk.PhysicalDevice,
) -> error.Error {
  count: u32

  vk.EnumerateDeviceExtensionProperties(physical_device, nil, &count, nil)
  available_extensions := make(
    []vk.ExtensionProperties,
    count,
    ctx.tmp_allocator,
  )

  vk.EnumerateDeviceExtensionProperties(
    physical_device,
    nil,
    &count,
    &available_extensions[0],
  )

  check :: proc(e: cstring, availables: []vk.ExtensionProperties) -> bool {
    for &available in availables do if e == cstring(&available.extensionName[0]) do return true

    return false
  }

  for ext in DEVICE_EXTENSIONS do if !check(ext, available_extensions) do return .ExtensionNotFound

  return nil
}

@(private)
find_physical_device :: proc(
  ctx: ^Vulkan_Context,
) -> (
  physical_device: vk.PhysicalDevice,
  err: error.Error,
) {
  device_count: u32
  vk.EnumeratePhysicalDevices(ctx.instance, &device_count, nil)

  devices := make([]vk.PhysicalDevice, device_count, ctx.tmp_allocator)

  vk.EnumeratePhysicalDevices(ctx.instance, &device_count, &devices[0])

  suitability :: proc(ctx: ^Vulkan_Context, dev: vk.PhysicalDevice) -> u32 {
    props: vk.PhysicalDeviceProperties
    features: vk.PhysicalDeviceFeatures

    vk.GetPhysicalDeviceProperties(dev, &props)
    vk.GetPhysicalDeviceFeatures(dev, &features)

    score: u32 = 10
    if props.deviceType == .DISCRETE_GPU do score += 1000

    if check_physical_device_ext_support(ctx, dev) != nil do return 0

    return score + props.limits.maxImageDimension2D
  }

  hiscore: u32 = 0
  for dev in devices {
    score := suitability(ctx, dev)
    if score > hiscore {
      physical_device = dev
      hiscore = score
    }
  }

  if hiscore == 0 do return physical_device, .PhysicalDeviceNotFound

  return physical_device, nil
}

@(private)
queues_indices :: proc(
  ctx: ^Vulkan_Context,
  flags: []vk.QueueFlag,
) -> (
  indices: []u32,
  err: error.Error,
) {
  indices_vec := vector.new(u32, u32(len(flags)), ctx.tmp_allocator) or_return
  founds_vec := vector.new(bool, u32(len(flags)), ctx.tmp_allocator) or_return

  queue_count: u32
  vk.GetPhysicalDeviceQueueFamilyProperties(
    ctx.physical_device,
    &queue_count,
    nil,
  )

  available_queues := vector.new(
    vk.QueueFamilyProperties,
    queue_count,
    ctx.tmp_allocator,
  ) or_return

  vec := vector.reserve_n(&available_queues, queue_count) or_return

  vk.GetPhysicalDeviceQueueFamilyProperties(
    ctx.physical_device,
    &queue_count,
    &vec[0],
  )

  indices = vector.reserve_n(&indices_vec, indices_vec.cap) or_return
  founds := vector.reserve_n(&founds_vec, founds_vec.cap) or_return

  for i in 0 ..< queue_count {
    for j in 0 ..< len(flags) {
      if flags[j] in vec[i].queueFlags && !founds[j] {
        indices[j] = u32(i)
        founds[j] = true
      }
    }
  }

  for found in founds {
    if !found do return indices, .FamilyIndiceNotComplete
  }

  return indices, nil
}

@(private)
device_create :: proc(
  ctx: ^Vulkan_Context,
) -> (
  device: Device,
  err: error.Error,
) {
  indices := queues_indices(ctx, {.GRAPHICS, .TRANSFER}) or_return
  device.indices[.Graphics] = indices[0]
  device.indices[.Transfer] = indices[1]

  device.queues = vector.new(Queue, u32(len(indices)), ctx.allocator) or_return

  MAX_QUEUE :: 10
  unique_indices: [MAX_QUEUE]u32

  for i in indices {
    // if i != indices[0] do panic("Not accepting diferent queue indices for now")
    unique_indices[i] += 1
  }

  queue_priority := f32(1.0)
  queue_create_infos := vector.new(
    vk.DeviceQueueCreateInfo,
    u32(len(indices)),
    ctx.tmp_allocator,
  ) or_return

  for k, i in unique_indices {
    if k == 0 do continue

    info := vk.DeviceQueueCreateInfo {
      sType            = .DEVICE_QUEUE_CREATE_INFO,
      queueFamilyIndex = u32(i),
      queueCount       = 1,
      pQueuePriorities = &queue_priority,
    }

    vector.append(&queue_create_infos, info) or_return
  }

  feature_info := vk.PhysicalDeviceVulkan13Features {
    sType            = .PHYSICAL_DEVICE_VULKAN_1_3_FEATURES,
    synchronization2 = true,
  }

  device_create_info := vk.DeviceCreateInfo {
    sType                   = .DEVICE_CREATE_INFO,
    pNext                   = &feature_info,
    enabledExtensionCount   = u32(len(DEVICE_EXTENSIONS)),
    ppEnabledExtensionNames = &DEVICE_EXTENSIONS[0],
    pQueueCreateInfos       = &queue_create_infos.data[0],
    queueCreateInfoCount    = queue_create_infos.len,
    pEnabledFeatures        = nil,
    enabledLayerCount       = 0,
  }

  if vk.CreateDevice(ctx.physical_device, &device_create_info, nil, &device.handle) != .SUCCESS do return device, .CreateDeviceFailed

  vk.load_proc_addresses_device(device.handle)

  return device, nil
}

@(private)
queue_get :: proc(
  ctx: ^Vulkan_Context,
  kind: Queue_Kind,
  command_pool_count: u32,
) -> (
  queue: ^Queue,
  err: error.Error,
) {
  queue = vector.one(&ctx.device.queues) or_return
  queue.indice = ctx.device.indices[kind]
  queue.command_pools = vector.new(
    Command_Pool,
    command_pool_count,
    ctx.allocator,
  ) or_return

  vk.GetDeviceQueue(ctx.device.handle, queue.indice, 0, &queue.handle)

  return queue, nil
}

drm_format :: proc(format: vk.Format) -> u32 {
  #partial switch format {
  case .B8G8R8A8_SRGB:
    return(
      (u32(u8('X'))) |
      (u32(u8('R')) << 8) |
      (u32(u8('2')) << 16) |
      (u32(u8('4')) << 24) \
    )
  }

  return 0
}

device_deinit :: proc(device: ^Device) {
  for i in 0 ..< device.queues.len {
    for j in 0 ..< device.queues.data[i].command_pools.len {
      vk.DestroyCommandPool(
        device.handle,
        device.queues.data[i].command_pools.data[j].handle,
        nil,
      )
    }
  }

  vk.DestroyDevice(device.handle, nil)
}
