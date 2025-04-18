package main

import "base:runtime"
import "core:fmt"
import "core:mem"

Error :: enum {
	OutOfMemory,
	FileNotFound,
	ReadFileFailed,
	AttributeKindNotFound,
	NumberParseFailed,
	CreateInstanceFailed,
	CreateBuffer,
	BeginCommandBufferFailed,
	EndCommandBufferFailed,
	AllocateCommandBufferFailed,
	VulkanLib,
	LayerNotFound,
	PhysicalDeviceNotFound,
	FamilyIndiceNotComplete,
	MemoryNotFound,
	EnviromentVariablesNotSet,
	WaylandSocketNotAvaiable,
	SendMessageFailed,
	BufferNotReleased,
	CreateDescriptorSetLayoutFailed,
	CreatePipelineFailed,
	GetImageModifier,
	AllocateDeviceMemory,
	CreateImageFailed,
	WaitFencesFailed,
	QueueSubmitFailed,
	CreateImageViewFailed,
	CreatePipelineLayouFailed,
	CreateDescriptorPoolFailed,
	CreateFramebufferFailed,
	GetFdFailed,
	SizeNotMatch,
	CreateShaderModuleFailed,
	AllocateDescriptorSetFailed,
	ExtensionNotFound,
	CreateDeviceFailed,
	CreateRenderPassFailed,
	CreateSemaphoreFailed,
	CreateFenceFailed,
	CreateCommandPoolFailed,
	SocketConnectFailed,
	GltfLoadFailed,
	InvalidKeymapInput,
	TypeAssertionFailed,
	IdentifierAssertionFailed,
	KeywordAssertionFailed,
	SymbolAssertionFailed,
	InvalidToken,
	CodeNotFound,
	UnregisteredKey,
}

main :: proc() {
	bytes: []u8
	err: Error
	arena: mem.Arena
	tmp_arena: mem.Arena

	wl: WaylandContext
	vk: VulkanContext
	// keymap: Keymap

	width: u32 = 1920
	height: u32 = 1080
	frames: u32 = 2

	if bytes, err = alloc([]u8, 1024 * 1024 * 2, context.allocator); err != nil {
		fmt.println("Error:", err)
		return
	}

	defer delete(bytes)

	mem.arena_init(&arena, bytes)
	context.allocator = mem.arena_allocator(&arena)

	mem.arena_init(&tmp_arena, make([]u8, 1024 * 1024 * 1, context.allocator))
	context.temp_allocator = mem.arena_allocator(&tmp_arena)

	if err = init(&vk, &wl, width, height, frames, &arena, &tmp_arena); err != nil {
		fmt.println("Error:", err)
		return
	}

	if err = loop(&vk, &wl, &arena, &tmp_arena); err != nil {
		fmt.println("Error:", err)
		return
	}

	deinit_wayland(&wl)
	deinit_vulkan(&vk)

	fmt.println("TMP", tmp_arena.offset, tmp_arena.peak_used)
	fmt.println("MAIN", arena.offset - len(tmp_arena.data), arena.peak_used - len(tmp_arena.data))
}

init :: proc(
	vk: ^VulkanContext,
	wl: ^WaylandContext,
	width: u32,
	height: u32,
	frames: u32,
	arena: ^mem.Arena,
	tmp_arena: ^mem.Arena,
) -> Error {
	init_vulkan(vk, 1920, 1080, frames, arena, tmp_arena) or_return
	init_wayland(wl, vk, width, height, frames, arena, tmp_arena) or_return

	return nil
}

loop :: proc(
	vk: ^VulkanContext,
	wl: ^WaylandContext,
	arena: ^mem.Arena,
	tmp_arena: ^mem.Arena,
) -> Error {
	mesh := gltf_from_file("assets/cube.gltf", vk.tmp_allocator) or_return

	count := u32(len(mesh.position.([][3]f32)))
	vertices := alloc([]Vertex, count, vk.tmp_allocator) or_return
	indices := mesh.indice.([]u16)

	{
		positions := mesh.position.([][3]f32)
		normals := mesh.normal.([][3]f32)
		textures := mesh.texture.([][2]f32)

		for i in 0 ..< count {
			vertices[i] = Vertex {
				position = positions[i],
				normal   = normals[i],
				texture  = textures[i],
			}
		}
	}

	width := f32(400)
	height := f32(400)
	model := matrix[4, 4]f32{
		width, 0, 0, width, 
		0, height, 0, -height, 
		0, 0, 1, 1, 
		0, 0, 0, 1, 
	}

	widget_model := model

	color := Color{1.0, 0.0, 0.0, 1.0}

	model1 := matrix[4, 4]f32{
		300, 0, 0, 100, 
		0, 50, 0, -50, 
		0, 0, 1, 0, 
		0, 0, 0, 1, 
	}

	model2 := matrix[4, 4]f32{
		300, 0, 0, 100, 
		0, 50, 0, -(50 + 5) * 2 - 50, 
		0, 0, 1, 0, 
		0, 0, 0, 1, 
	}

	model3 := matrix[4, 4]f32{
		300, 0, 0, 100, 
		0, 50, 0, -(50 + 5) * 4 - 50, 
		0, 0, 1, 0, 
		0, 0, 0, 1, 
	}

	color1 := Color{1.0, 1.0, 1.0, 1.0}
	color2 := Color{0.0, 0.0, 1.0, 1.0}
	color3 := Color{1.0, 0.0, 1.0, 1.0}

	geometry := geometry_create(vk, vertices, indices, 4) or_return
	widget := widget_create(vk, geometry, widget_model, color, 3) or_return

	instance1 := widget_add_child(vk, widget, geometry, model1, color1) or_return
	instance2 := widget_add_child(vk, widget, geometry, model2, color2) or_return
	instance3 := widget_add_child(vk, widget, geometry, model3, color3) or_return

	i: i32 = 0

	for wl.running {
		mark := mem.begin_arena_temp_memory(tmp_arena)
		defer mem.end_arena_temp_memory(mark)

		// widget_model[1, 3] = model[1, 3] - f32(i % 400)
		// widget_update(vk, quad_widget, widget_model) or_return

		if render(wl) != nil {
			fmt.println("Failed to render frame")
		}

		i += 20
	}

	return nil
}

alloc :: proc($T: typeid/[]$E, count: u32, allocator: runtime.Allocator) -> ([]E, Error) {
	if array, err := make(T, count, allocator); err == nil {
		return array, nil
	}

	return nil, .OutOfMemory
}
