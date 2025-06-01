package vulk

import "core:log"
import "core:os"
import "core:strings"
import vk "vendor:vulkan"

import "lib:collection/vector"
import "lib:error"

Shader_Module :: struct {
  path:   string,
  handle: vk.ShaderModule,
}

@(private)
shader_module_update :: proc(
  module: ^Shader_Module,
  ctx: ^Vulkan_Context,
) -> error.Error {
  er: os.Error
  file: os.Handle
  size: i64

  if file, er = os.open(module.path); er != nil {
    log.error("File", module.path, "does not exist")
    return .FileNotFound
  }

  defer os.close(file)

  if size, er = os.file_size(file); er != nil {
    log.error("Failed to tell file", module.path, "size")
    return .FileNotFound
  }

  buf := make([]u8, u32(size), ctx.tmp_allocator)

  l: int
  if l, er = os.read(file, buf); er != nil {
    log.error("Failed to read file", module.path)
    return .ReadFileFailed
  }

  if int(size) != l do return .SizeNotMatch

  info := vk.ShaderModuleCreateInfo {
    sType    = .SHADER_MODULE_CREATE_INFO,
    codeSize = int(size),
    pCode    = cast([^]u32)(&buf[0]),
  }

  if vk.CreateShaderModule(ctx.device.handle, &info, nil, &module.handle) !=
     .SUCCESS {
    log.error("Failed to create shader", module.path, "module")
    return .CreateShaderModuleFailed
  }

  return nil
}

update_shaders :: proc(ctx: ^Vulkan_Context) -> error.Error {
  log.info("Updating shaders")

  for i in 0 ..< ctx.shaders.len {
    shader_module_update(&ctx.shaders.data[i], ctx) or_return
  }

  for j in 0 ..< ctx.render_passes.len {
    for i in 0 ..< ctx.render_passes.data[j].pipelines.len {
      vector.append(
        &ctx.render_passes.data[j].unused,
        ctx.render_passes.data[j].pipelines.data[i],
      ) or_return

      pipeline_update(
        &ctx.render_passes.data[j].pipelines.data[i],
        ctx,
        &ctx.render_passes.data[j],
      ) or_return
    }
  }

  for i in 0 ..< ctx.shaders.len {
    shader_module_destroy(ctx, &ctx.shaders.data[i])
  }

  return nil
}

@(private)
shader_module_create :: proc(
  module: ^Shader_Module,
  ctx: ^Vulkan_Context,
  path: string,
) -> error.Error {
  module.path = strings.clone(path, ctx.allocator)
  shader_module_update(module, ctx) or_return

  return nil
}

shader_module_destroy :: proc(ctx: ^Vulkan_Context, module: ^Shader_Module) {
  vk.DestroyShaderModule(ctx.device.handle, module.handle, nil)
}
