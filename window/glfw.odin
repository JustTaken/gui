#+build darwin, windows

package window

import vk "vendor:vulkan"
import glfw "vendor:glfw"

Window :: glfw.WindowHandle

new :: proc() -> Window {
  self: Window

  glfw.Init()
    
  glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
  glfw.WindowHint(glfw.RESIZABLE, 0)
    
	self = glfw.CreateWindow(800, 600, "Vulkan", nil, nil)
	glfw.SetFramebufferSizeCallback(self, resizeCallback)

  return self
}

pollEvents :: proc(_: Window) {
  glfw.PollEvents()
}

deinit :: proc(win: Window) {
  glfw.DestroyWindow(Window(win));
  glfw.Terminate();
}

shouldClose :: proc(win: Window) -> b32 {
  return glfw.WindowShouldClose(Window(win))
}

getExtensions :: proc(win: Window) -> []cstring {
  return glfw.GetRequiredInstanceExtensions()
}

createSurface :: proc(win: Window, instance: vk.Instance, surface: ^vk.SurfaceKHR) -> vk.Result {
  return glfw.CreateWindowSurface(instance, Window(win), nil, surface)
}

getSize :: proc(win: Window) -> (u32, u32) {
  width, height: i32 = glfw.GetFramebufferSize(Window(win))
  return u32(width), u32(height)
}

waitWindowEvents :: proc() {
  glfw.WaitEvents()
}

_resized: bool
resizeCallback :: proc "c" (win: Window, width, height: i32) {
  _resized = true;
}

resized :: proc(_: Window) -> bool {
  return _resized
}
