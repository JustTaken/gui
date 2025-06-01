package vulk

import "core:image/png"
import "core:log"
import "core:strings"
import vk "vendor:vulkan"

import "lib:collection/vector"
import "lib:error"

@(private)
Image_Sampler :: struct {
  handle: vk.Sampler,
}

@(private)
Image :: struct {
  handle:  vk.Image,
  memory:  vk.DeviceMemory,
  view:    vk.ImageView,
  sampler: Maybe(Image_Sampler),
  width:   u32,
  height:  u32,
  format:  vk.Format,
  aspect:  vk.ImageAspectFlags,
}

image_create :: proc(
  image: ^Image,
  ctx: ^Vulkan_Context,
  width: u32,
  height: u32,
  format: vk.Format,
  type: vk.ImageType,
  tiling: vk.ImageTiling,
  usage: vk.ImageUsageFlags,
  properties: vk.MemoryPropertyFlags,
  flags: vk.ImageCreateFlags = {},
  aspect: vk.ImageAspectFlags,
  image_pNext: rawptr = nil,
  memory_pNext: rawptr = nil,
) -> error.Error {
  image.width = width
  image.height = height
  image.aspect = aspect
  image.format = format

  info := vk.ImageCreateInfo {
    sType = .IMAGE_CREATE_INFO,
    pNext = image_pNext,
    flags = flags,
    imageType = type,
    format = format,
    mipLevels = 1,
    arrayLayers = 1,
    samples = {._1},
    tiling = tiling,
    usage = usage,
    sharingMode = .EXCLUSIVE,
    queueFamilyIndexCount = 0,
    pQueueFamilyIndices = nil,
    initialLayout = .UNDEFINED,
    extent = vk.Extent3D {
      width = image.width,
      height = image.height,
      depth = 1,
    },
  }

  if res := vk.CreateImage(ctx.device.handle, &info, nil, &image.handle);
     res != .SUCCESS {
    return .CreateImageFailed
  }

  image_memory_create(ctx, image, properties, memory_pNext) or_return
  image_view_create(ctx, image) or_return

  return nil
}

@(private)
image_memory_create :: proc(
  ctx: ^Vulkan_Context,
  image: ^Image,
  properties: vk.MemoryPropertyFlags,
  pNext: rawptr,
) -> error.Error {
  requirements: vk.MemoryRequirements
  vk.GetImageMemoryRequirements(ctx.device.handle, image.handle, &requirements)

  alloc_info := vk.MemoryAllocateInfo {
    sType           = .MEMORY_ALLOCATE_INFO,
    pNext           = pNext,
    allocationSize  = requirements.size,
    memoryTypeIndex = find_memory_type(
      ctx,
      requirements.memoryTypeBits,
      properties,
    ) or_return,
  }

  if vk.AllocateMemory(ctx.device.handle, &alloc_info, nil, &image.memory) !=
     .SUCCESS {
    return .AllocateDeviceMemory
  }

  vk.BindImageMemory(
    ctx.device.handle,
    image.handle,
    image.memory,
    vk.DeviceSize(0),
  )

  return nil
}

@(private)
image_view_create :: proc(ctx: ^Vulkan_Context, image: ^Image) -> error.Error {
  range := vk.ImageSubresourceRange {
    aspectMask     = image.aspect,
    levelCount     = 1,
    layerCount     = 1,
    baseMipLevel   = 0,
    baseArrayLayer = 0,
  }

  info := vk.ImageViewCreateInfo {
    sType            = .IMAGE_VIEW_CREATE_INFO,
    image            = image.handle,
    format           = image.format,
    viewType         = .D2,
    subresourceRange = range,
  }

  if vk.CreateImageView(ctx.device.handle, &info, nil, &image.view) !=
     .SUCCESS {
    return .CreateImageViewFailed
  }

  return nil
}

@(private)
image_sampler_create :: proc(
  ctx: ^Vulkan_Context,
  image: ^Image,
) -> error.Error {
  properties: vk.PhysicalDeviceProperties
  vk.GetPhysicalDeviceProperties(ctx.physical_device, &properties)

  info := vk.SamplerCreateInfo {
    sType                   = .SAMPLER_CREATE_INFO,
    magFilter               = .LINEAR,
    minFilter               = .LINEAR,
    addressModeU            = .REPEAT,
    addressModeV            = .REPEAT,
    addressModeW            = .REPEAT,
    maxAnisotropy           = properties.limits.maxSamplerAnisotropy,
    anisotropyEnable        = true,
    borderColor             = .INT_OPAQUE_BLACK,
    unnormalizedCoordinates = false,
    compareEnable           = false,
    compareOp               = .ALWAYS,
    mipmapMode              = .LINEAR,
    mipLodBias              = 0,
    minLod                  = 0,
    maxLod                  = 0,
  }

  sampler: Image_Sampler
  if vk.CreateSampler(ctx.device.handle, &info, nil, &sampler.handle) !=
     .SUCCESS {
    return .SamplerCreateFailed
  }

  image.sampler = sampler
  return nil
}

@(private)
transition_image_layout :: proc(
  ctx: ^Vulkan_Context,
  image: ^Image,
  old_layout: vk.ImageLayout,
  new_layout: vk.ImageLayout,
  src_access_mask: vk.AccessFlags,
  dst_access_mask: vk.AccessFlags,
  src_stage: vk.PipelineStageFlags,
  dst_stage: vk.PipelineStageFlags,
  aspect: vk.ImageAspectFlags,
) {
  range := vk.ImageSubresourceRange {
    aspectMask     = aspect,
    levelCount     = 1,
    baseArrayLayer = 0,
    layerCount     = 1,
  }

  barrier := vk.ImageMemoryBarrier {
    sType               = .IMAGE_MEMORY_BARRIER,
    oldLayout           = old_layout,
    newLayout           = new_layout,
    srcQueueFamilyIndex = 0,
    dstQueueFamilyIndex = 0,
    image               = image.handle,
    subresourceRange    = range,
    srcAccessMask       = src_access_mask,
    dstAccessMask       = dst_access_mask,
  }

  vk.CmdPipelineBarrier(
    ctx.transfer_command_buffer.handle,
    src_stage,
    dst_stage,
    {},
    0,
    nil,
    0,
    nil,
    1,
    &barrier,
  )
}

@(private)
image_from_file :: proc(
  ctx: ^Vulkan_Context,
  path: string,
) -> (
  image: ^Image,
  err: error.Error,
) {
  img: ^png.Image
  er: png.Error
  if img, er = png.load_from_file(path, {}, ctx.tmp_allocator); er != nil {
    log.error("FILED TO READ PNG FILE:", er)
    return image, .InvalidImage
  }

  if img.depth != 8 do return image, .InvalidImage
  assert(len(img.pixels.buf[:]) >= img.width * img.height * img.channels)

  image = vector.one(&ctx.images) or_return

  image_create(
    image,
    ctx,
    format = .R8G8B8A8_SRGB,
    type = .D2,
    tiling = .OPTIMAL,
    usage = {.TRANSFER_DST, .SAMPLED},
    properties = {.DEVICE_LOCAL},
    width = u32(img.width),
    height = u32(img.height),
    aspect = {.COLOR},
  ) or_return

  transition_image_layout(
    ctx,
    image,
    .UNDEFINED,
    .TRANSFER_DST_OPTIMAL,
    {},
    {.TRANSFER_WRITE},
    {.TOP_OF_PIPE},
    {.TRANSFER},
    {.COLOR},
  )

  copy_data_to_image(
    ctx,
    img.pixels.buf[:],
    image,
    u32(img.width),
    u32(img.height),
    {.COLOR},
  ) or_return

  transition_image_layout(
    ctx,
    image,
    .TRANSFER_DST_OPTIMAL,
    .SHADER_READ_ONLY_OPTIMAL,
    {.TRANSFER_WRITE},
    {.SHADER_READ},
    {.TRANSFER},
    {.FRAGMENT_SHADER},
    {.COLOR},
  )

  return image, nil
}

@(private)
image_destroy :: proc(ctx: ^Vulkan_Context, image: ^Image) {
  if image.sampler != nil {
    vk.DestroySampler(ctx.device.handle, image.sampler.?.handle, nil)
  }

  vk.DestroyImageView(ctx.device.handle, image.view, nil)
  vk.DestroyImage(ctx.device.handle, image.handle, nil)
  vk.FreeMemory(ctx.device.handle, image.memory, nil)
}
