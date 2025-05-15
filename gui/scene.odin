package main

import "collection/gltf"
import vk "vulkan"
import "error"
import "core:mem"
import "collection"

Model_Instance :: struct {
	parent: ^Model,
	ids: collection.Vector(u32),
	children: collection.Vector(Model_Instance),
}

Scene_Instance :: struct {
	models: collection.Vector(Model_Instance),
}

Scene :: struct {
	models: collection.Vector(Model),
}

Model :: struct {
	geometries: collection.Vector(u32),
	children: collection.Vector(Model),
}

scene_instance_create :: proc(ctx: ^Context, scene: ^Scene) -> (instance: Scene_Instance, err: error.Error) {
	instance.models = collection.new_vec(Model_Instance, scene.models.len, ctx.vk.allocator) or_return

	for i in 0..<scene.models.len {
		collection.vec_append(&instance.models, model_instance_create(ctx, &scene.models.data[i]) or_return) or_return
	}

	return instance, nil
}

model_instance_create :: proc(ctx: ^Context, model: ^Model) -> (instance: Model_Instance, err: error.Error) {
	instance.ids = collection.new_vec(u32, model.geometries.len, ctx.vk.allocator) or_return
	instance.children = collection.new_vec(Model_Instance, model.children.len, ctx.vk.allocator) or_return

	for i in 0..<model.children.len {
		collection.vec_append(&instance.children, model_instance_create(ctx, &model.children.data[i]) or_return) or_return
	}

	for i in 0..<model.geometries.len {
	    instance.ids.data[i] = vk.geometry_instance_add(&ctx.vk, model.geometries.data[i], nil, {0, 1, 1, 1}) or_return
	}

	return instance, nil
}

load_mesh :: proc(ctx: ^Context, mesh: ^gltf.Mesh, transform: matrix[4, 4]f32) -> (geometries: collection.Vector(u32), err: error.Error) {
  Vertex :: struct {
    position: [3]f32,
    normal: [3]f32,
    texture: [2]f32,
  }

  geometries = collection.new_vec(u32, u32(len(mesh.primitives)), ctx.vk.allocator) or_return

  for primitive in mesh.primitives {
    positions := primitive.accessors[.Position]
    normals := primitive.accessors[.Normal]
    textures := primitive.accessors[.Texture0]

    assert(positions.component_kind == .F32 && positions.component_count == 3)
    assert(normals.component_kind == .F32 && normals.component_count == 3)
    assert(textures.component_kind == .F32 && textures.component_count == 2)
    assert(size_of(Vertex) == (size_of(f32) * positions.component_count) + (size_of(f32) * normals.component_count) + (size_of(f32) * textures.component_count))

    count := positions.count
    size := size_of(Vertex) * count

    indices := primitive.indices
    bytes := make([]u8, size, ctx.vk.tmp_allocator)

    pos := cast([^][3]f32)raw_data(positions.bytes)
    norms := cast([^][3]f32)raw_data(normals.bytes)
    texts := cast([^][2]f32)raw_data(textures.bytes)
    vertices := cast([^]Vertex)raw_data(bytes)

    for i in 0..<count {
      vertices[i].position = pos[i]
      vertices[i].normal = norms[i]
      vertices[i].texture = texts[i]
    }

    geometry := vk.geometry_create(&ctx.vk, bytes, size_of(Vertex), count, indices.bytes, gltf.get_accessor_size(indices), indices.count, 1, transform) or_return
    collection.vec_append(&geometries, geometry) or_return
  }

  return geometries, nil
}

load_node :: proc(ctx: ^Context, node: ^gltf.Node) -> (model: Model, err: error.Error) {
	model.children = collection.new_vec(Model, u32(len(node.children)), ctx.vk.allocator) or_return

	for child in node.children {
		collection.vec_append(&model.children, load_node(ctx, child) or_return) or_return
	}

	if node.mesh == nil do return model, nil

	model.geometries = load_mesh(ctx, node.mesh, node.transform) or_return

	return model, nil
}

load_gltf_scene :: proc(ctx: ^Context, path: string) -> (scene_ptr: ^Scene, err: error.Error) {
	scene: Scene

	mark := mem.begin_arena_temp_memory(ctx.vk.tmp_arena)
	defer mem.end_arena_temp_memory(mark)

	glt := gltf.from_file(path, ctx.vk.tmp_allocator) or_return
	gltf_scene := &glt.scenes["Scene"]

	scene.models = collection.new_vec(Model, u32(len(gltf_scene.nodes)), ctx.vk.allocator) or_return

	for j in 0..<len(gltf_scene.nodes) {
		collection.vec_append(&scene.models, load_node(ctx, gltf_scene.nodes[j]) or_return) or_return
	}

	collection.vec_append(&ctx.scenes, scene) or_return

	return &ctx.scenes.data[ctx.scenes.len - 1], nil
}
