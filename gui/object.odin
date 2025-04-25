package main

import "core:fmt"
import vk "vendor:vulkan"

Indice :: u16
InstanceModel :: matrix[4, 4]f32
Color :: [4]f32
Vertex :: struct {
	position: [3]f32,
	normal:   [3]f32,
	texture:  [2]f32,
}

Geometry :: struct {
	vertex:          vk.Buffer,
	memory:          vk.DeviceMemory,
	indice:          vk.Buffer,
	indice_memory:   vk.DeviceMemory,
	count:           u32,
	instance_offset: u32,
	instance_count:  u32,
}

Instance :: struct {
	geometry_id: u32,
	model:       InstanceModel,
	id:          u32,
}

Widget :: struct {
	geometry_id: u32,
	id:          u32,
	model:       InstanceModel,
	childs:      []Instance,
	childs_len:  u32,
}

widgets_init :: proc(ctx: ^Vulkan_Context, count: u32) -> Error {
	ctx.widgets = alloc([]Widget, count, ctx.allocator) or_return
	ctx.widgets_len = 0

	return nil
}

widget_create :: proc(
	ctx: ^Vulkan_Context,
	geometry_id: u32,
	model: InstanceModel,
	color: Color,
	count: u32,
) -> (
	id: u32,
	ok: Error,
) {
	widget := &ctx.widgets[ctx.widgets_len]
	widget.model = model

	widget.geometry_id = geometry_id
	widget.childs = alloc([]Instance, count, ctx.allocator) or_return
	widget.childs_len = 0
	widget.id = geometry_add_instance(ctx, geometry_id, widget.model, color) or_return

	id = ctx.widgets_len
	ctx.widgets_len += 1

	return id, nil
}

widget_add_child :: proc(
	ctx: ^Vulkan_Context,
	widget_id: u32,
	geometry_id: u32,
	model: InstanceModel,
	color: Color,
) -> (
	id: u32,
	err: Error,
) {
	widget := &ctx.widgets[widget_id]

	instance_model := relative_top_left(widget.model, model)
	id = geometry_add_instance(ctx, geometry_id, instance_model, color) or_return

	widget.childs[widget.childs_len].geometry_id = geometry_id
	widget.childs[widget.childs_len].model = model
	widget.childs[widget.childs_len].id = id

	id = widget.childs_len
	widget.childs_len += 1

	return id, nil
}

widget_update :: proc(ctx: ^Vulkan_Context, widget_id: u32, model: InstanceModel) -> Error {
	widget := &ctx.widgets[widget_id]
	widget.model = model
	geometry_update_instance(ctx, widget.geometry_id, widget.id, model, nil) or_return

	for i in 0 ..< widget.childs_len {
		instance := &widget.childs[i]
		instance_model := relative_top_left(widget.model, instance.model)

		geometry_update_instance(
			ctx,
			instance.geometry_id,
			instance.id,
			instance_model,
			nil,
		) or_return
	}

	return nil
}

relative_top_left :: proc(parent_model: InstanceModel, model: InstanceModel) -> InstanceModel {
	relative := model

	relative[0, 3] += parent_model[0, 3] + (model[0, 0] - parent_model[0, 0])
	relative[1, 3] += parent_model[1, 3] - (model[1, 1] - parent_model[1, 1])
	relative[2, 3] += parent_model[2, 3] - 0.001

	return relative
}

geometries_init :: proc(ctx: ^Vulkan_Context, count: u32, max_instances: u32) -> Error {
	ctx.geometries = alloc([]Geometry, count, ctx.allocator) or_return
	ctx.geometries_len = 0
	ctx.max_instances = 0

	ctx.uniform_buffer = vulkan_buffer_create(
		ctx.device,
		size_of(Projection),
		{.UNIFORM_BUFFER, .TRANSFER_DST},
	) or_return

	ctx.uniform_buffer_memory = vulkan_buffer_create_memory(
		ctx.device,
		ctx.physical_device,
		ctx.uniform_buffer,
		{.DEVICE_LOCAL},
	) or_return

	ctx.model_buffer = vulkan_buffer_create(
		ctx.device,
		vk.DeviceSize(size_of(InstanceModel) * max_instances),
		{.STORAGE_BUFFER, .TRANSFER_DST},
	) or_return

	ctx.model_buffer_memory = vulkan_buffer_create_memory(
		ctx.device,
		ctx.physical_device,
		ctx.model_buffer,
		{.DEVICE_LOCAL},
	) or_return

	ctx.color_buffer = vulkan_buffer_create(
		ctx.device,
		vk.DeviceSize(size_of(Color) * max_instances),
		{.STORAGE_BUFFER, .TRANSFER_DST},
	) or_return

	ctx.color_buffer_memory = vulkan_buffer_create_memory(
		ctx.device,
		ctx.physical_device,
		ctx.color_buffer,
		{.DEVICE_LOCAL},
	) or_return

	return nil
}

geometry_create :: proc(
	ctx: ^Vulkan_Context,
	vertices: []Vertex,
	indices: []Indice,
	max_instances: u32,
) -> (
	id: u32,
	err: Error,
) {
	id = ctx.geometries_len
	geometry := &ctx.geometries[id]

	size := vk.DeviceSize(size_of(Vertex) * len(vertices))
	geometry.vertex = vulkan_buffer_create(
		ctx.device,
		size,
		{.VERTEX_BUFFER, .TRANSFER_DST},
	) or_return

	geometry.memory = vulkan_buffer_create_memory(
		ctx.device,
		ctx.physical_device,
		geometry.vertex,
		{.DEVICE_LOCAL},
	) or_return

	offset := vulkan_buffer_copy_data(Vertex, ctx, vertices[:])
	vulkan_buffer_copy(ctx, geometry.vertex, size, 0, offset) or_return

	size = vk.DeviceSize(size_of(Indice) * len(indices))
	geometry.indice = vulkan_buffer_create(
		ctx.device,
		size,
		{.INDEX_BUFFER, .TRANSFER_DST},
	) or_return

	geometry.indice_memory = vulkan_buffer_create_memory(
		ctx.device,
		ctx.physical_device,
		geometry.indice,
		{.DEVICE_LOCAL},
	) or_return

	offset = vulkan_buffer_copy_data(Indice, ctx, indices[:])
	vulkan_buffer_copy(ctx, geometry.indice, size, 0, offset) or_return

	geometry.instance_offset = ctx.max_instances
	geometry.instance_count = 0
	geometry.count = u32(len(indices))

	ctx.max_instances += max_instances
	ctx.geometries_len += 1

	return id, nil
}

geometry_add_instance :: proc(
	ctx: ^Vulkan_Context,
	geometry_id: u32,
	model: InstanceModel,
	color: Color,
) -> (
	id: u32,
	ok: Error,
) {
	geometry := &ctx.geometries[geometry_id]
	id = geometry.instance_count

	geometry_update_instance(ctx, geometry_id, id, model, color) or_return

	geometry.instance_count += 1

	return id, nil
}

geometry_update_instance :: proc(
	ctx: ^Vulkan_Context,
	geometry_id: u32,
	id: u32,
	model: Maybe(InstanceModel),
	color: Maybe(Color),
) -> Error {
	geometry := &ctx.geometries[geometry_id]

	if model != nil {
		models := [?]InstanceModel{model.?}
		offset := vulkan_buffer_copy_data(InstanceModel, ctx, models[:])

		vulkan_buffer_copy(
			ctx,
			ctx.model_buffer,
			size_of(InstanceModel),
			vk.DeviceSize(geometry.instance_offset + id) * size_of(InstanceModel),
			offset,
		) or_return
	}

	if color != nil {
		colors := [?]Color{color.?}
		offset := vulkan_buffer_copy_data(Color, ctx, colors[:])

		vulkan_buffer_copy(
			ctx,
			ctx.color_buffer,
			size_of(Color),
			vk.DeviceSize(geometry.instance_offset + id) * size_of(Color),
			offset,
		) or_return
	}

	return nil
}

destroy_geometry :: proc(device: vk.Device, geometry: ^Geometry) {
	vk.DestroyBuffer(device, geometry.vertex, nil)
	vk.FreeMemory(device, geometry.memory, nil)
	vk.DestroyBuffer(device, geometry.indice, nil)
	vk.FreeMemory(device, geometry.indice_memory, nil)
}
