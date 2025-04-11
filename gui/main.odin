package main

import "core:fmt"
import "core:mem"
import "core:time"

main :: proc() {
	bytes: []u8
	arena: mem.Arena
	tmp_arena: mem.Arena

	wl: WaylandContext
	vk: VulkanContext

	width: u32 = 1920
	height: u32 = 1080
	frames: u32 = 2

	if bytes = make([]u8, 1024 * 1024 * 2); bytes == nil do panic("Out of memory")
	defer delete(bytes)

	mem.arena_init(&arena, bytes)
	context.allocator = mem.arena_allocator(&arena)

	mem.arena_init(&tmp_arena, make([]u8, 1024 * 1024 * 1, context.allocator))
	context.temp_allocator = mem.arena_allocator(&tmp_arena)

	if !init(&vk, &wl, width, height, frames, &arena, &tmp_arena) do panic("Failed to initialize")

	loop(&vk, &wl, &arena, &tmp_arena)

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
) -> bool {
	init_vulkan(vk, 1920, 1080, frames, arena, tmp_arena) or_return

	init_wayland(wl, vk, width, height, frames, arena, tmp_arena) or_return

	return true
}

loop :: proc(
	vk: ^VulkanContext,
	wl: ^WaylandContext,
	arena: ^mem.Arena,
	tmp_arena: ^mem.Arena,
) -> bool {
	geometries := make([]^Geometry, 10, context.allocator)

	triangle_vertices := [?]Vertex {
		{position = {-1.0, -1.0}},
		{position = {0.0, 1.0}},
		{position = {1.0, -1.0}},
	}

	quad_vertices := [?]Vertex {
		{position = {-1.0, -1.0}},
		{position = {-1.0, 1.0}},
		{position = {1.0, -1.0}},
		{position = {1.0, -1.0}},
		{position = {-1.0, 1.0}},
		{position = {1.0, 1.0}},
	}

	triangle_model := matrix[4, 4]f32{
		400, 0, 0, 0, 
		0, 400, 0, 0, 
		0, 0, 1, 1, 
		0, 0, 0, 1, 
	}

	triangle_color := [3]f32{1.0, 1.0, 0.0}

	quad_model := matrix[4, 4]f32{
		400, 0, 0, 0, 
		0, 400, 0, 0, 
		0, 0, 1, 1, 
		0, 0, 0, 1, 
	}

	quad_color := [3]f32{1.0, 1.0, 0.0}

	geometries[0] = add_geometry(vk, triangle_vertices[:], 1) or_return
	geometries[1] = add_geometry(vk, quad_vertices[:], 1) or_return

	triangle_id := add_geometry_instance(
		vk,
		geometries[0],
		triangle_model,
		triangle_color,
	) or_return
	quad_id := add_geometry_instance(vk, geometries[1], quad_model, quad_color) or_return

	i: i32 = 0

	for wl.running {
		mark := mem.begin_arena_temp_memory(tmp_arena)
		defer mem.end_arena_temp_memory(mark)

		triangle_model[0, 3] = f32(i % 400)
		quad_model[1, 3] = -f32(i % 400)

		update_geometry_instance(vk, geometries[0], triangle_id, triangle_model, nil) or_return
		update_geometry_instance(vk, geometries[1], quad_id, quad_model, nil) or_return

		if !render(wl) {
			fmt.println("Failed to render frame")
		}

		i += 1
	}

	return true
}
