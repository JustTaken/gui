package main

import "collection/gltf"
import vk "vulkan"
import "error"
import "core:mem"
import "collection"
import "core:log"
import "core:math/linalg"

Matrix :: matrix[4, 4]f32

Scene_Animation :: struct {
	time_stamp: []f32,
	transforms: [][]Matrix,
}

On_Going_Animation :: struct {
	start: i64,
	ref: ^Scene_Animation,
}

Model_Instance :: struct {
	model: ^Model,
	instances: collection.Vector(^vk.Instance),
	bones: collection.Vector(Scene_Instance),
	children: collection.Vector(Model_Instance),
}

Scene_Instance :: struct {
	scene: ^Scene,
	models: collection.Vector(Model_Instance),
	on_going: Maybe(On_Going_Animation),
}

Scene :: struct {
	models: collection.Vector(Model),
	animations: collection.Vector(Scene_Animation),
	bind_pose_transforms: collection.Vector(Matrix),
}

Model :: struct {
	geometries: collection.Vector(^vk.Geometry),
	children: collection.Vector(Model),
	bones: collection.Vector(Matrix),
}

tick_scene_animation :: proc(instance: ^Scene_Instance, time: i64) {
	if instance.on_going == nil do return
	on_going := instance.on_going.?

	delta := time - on_going.start
}

play_scene_animation :: proc(instance: ^Scene_Instance, index: u32, time: i64) {
	on_going: On_Going_Animation
	on_going.ref = &instance.scene.animations.data[index]
	on_going.start = time

	instance.on_going = on_going
}

scene_instance_create :: proc(ctx: ^Context, scene: ^Scene, transform: Matrix) -> (instance: Scene_Instance, err: error.Error) {
	instance.scene = scene
	instance.models = collection.new_vec(Model_Instance, scene.models.len, ctx.allocator) or_return

	for i in 0..<scene.models.len {
		collection.vec_append(&instance.models, model_instance_create(ctx, &scene.models.data[i], transform) or_return) or_return
	}

	return instance, nil
}

model_instance_create :: proc(ctx: ^Context, model: ^Model, transform: Matrix) -> (instance: Model_Instance, err: error.Error) {
	instance.model = model
	instance.instances = collection.new_vec(^vk.Instance, model.geometries.len, ctx.allocator) or_return
	instance.bones = collection.new_vec(Scene_Instance, model.bones.len, ctx.allocator) or_return
	instance.children = collection.new_vec(Model_Instance, model.children.len, ctx.allocator) or_return

	for i in 0..<model.bones.len {
		collection.vec_append(&instance.bones, scene_instance_create(ctx, ctx.bone, transform * model.bones.data[i]) or_return) or_return
	}

	for i in 0..<model.children.len {
		collection.vec_append(&instance.children, model_instance_create(ctx, &model.children.data[i], transform) or_return) or_return
	}

	for i in 0..<model.geometries.len {
	    collection.vec_append(&instance.instances, vk.geometry_instance_add(&ctx.vk, model.geometries.data[i], transform, {0, 1, 1, 1}) or_return) or_return
	}

	return instance, nil
}

load_mesh :: proc(ctx: ^Context, mesh: ^gltf.Mesh, transform: Matrix) -> (geometries: collection.Vector(^vk.Geometry), err: error.Error) {
  Vertex :: struct {
    position: [3]f32,
    normal: [3]f32,
    texture: [2]f32,
    weight: [4]f32,
    joint: [4]u32,
  }

  geometries = collection.new_vec(^vk.Geometry, u32(len(mesh.primitives)), ctx.allocator) or_return

  for primitive in mesh.primitives {
    positions := primitive.accessors[.Position]
    normals := primitive.accessors[.Normal]
    textures := primitive.accessors[.Texture0]
    weights := primitive.accessors[.Weight0]
    joints := primitive.accessors[.Joint0]

    assert(positions.component_kind == .F32 && positions.component_count == 3)
    assert(normals.component_kind == .F32 && normals.component_count == 3)
    assert(textures.component_kind == .F32 && textures.component_count == 2)
    assert(weights.component_kind == .F32 && weights.component_count == 4)
    assert(joints.component_kind == .U8 && joints.component_count == 4)

    assert(size_of(Vertex) == (size_of(u32) * joints.component_count) + (size_of(f32) * weights.component_count) + (size_of(f32) * positions.component_count) + (size_of(f32) * normals.component_count) + (size_of(f32) * textures.component_count))

    count := positions.count

    indices := primitive.indices
    bytes := make([]u8, size_of(Vertex) * count, ctx.vk.tmp_allocator)

    pos := cast([^][3]f32)raw_data(positions.bytes)
    norms := cast([^][3]f32)raw_data(normals.bytes)
    texts := cast([^][2]f32)raw_data(textures.bytes)
    weigh := cast([^][4]f32)raw_data(weights.bytes)
    joint := cast([^][4]u8)raw_data(joints.bytes)

    vertices := cast([^]Vertex)raw_data(bytes)

    for i in 0..<count {
      vertices[i].position = pos[i]
      vertices[i].normal = norms[i]
      vertices[i].texture = texts[i]
      vertices[i].weight = weigh[i]
      vertices[i].joint = {u32(joint[i][0]), u32(joint[i][1]), u32(joint[i][2]), u32(joint[i][3])}
    }

    collection.vec_append(&geometries, vk.geometry_create(&ctx.vk, bytes, size_of(Vertex), count, indices.bytes, gltf.get_accessor_size(indices), indices.count, 1, transform, false) or_return) or_return
  }

  return geometries, nil
}

load_node :: proc(ctx: ^Context, glt: ^gltf.Gltf, node: u32) -> (model: Model, err: error.Error) {
	model.children = collection.new_vec(Model, u32(len(glt.nodes[node].children)), ctx.allocator) or_return

	for child in glt.nodes[node].children {
		collection.vec_append(&model.children, load_node(ctx, glt, child) or_return) or_return
	}

	// if glt.nodes[node].skin != nil {
	// 	model.bones = collection.new_vec(Matrix, u32(len(glt.nodes[node].skin.joints)), ctx.allocator) or_return

	// 	for joint in glt.nodes[node].skin.joints {
	// 		collection.vec_append(&model.bones, glt.nodes[joint].transform) or_return
	// 	}

	// 	return model, nil
	// }

	if glt.nodes[node].mesh == nil do return model, nil

	model.geometries = load_mesh(ctx, glt.nodes[node].mesh, glt.nodes[node].transform) or_return

	return model, nil
}

load_animation :: proc(ctx: ^Context, glt: ^gltf.Gltf, name: string) -> Scene_Animation {
	animation: Scene_Animation

	ref := glt.animations[name]

	animation.time_stamp = make([]f32, len(ref.frames), ctx.allocator)
	animation.transforms = make([][]Matrix, len(ref.frames), ctx.allocator)

	for i in 0..<len(ref.frames) {
		animation.time_stamp[i] = ref.frames[i].time
		animation.transforms[i] = make([]Matrix, len(ref.frames[i].transforms), ctx.allocator)

		for k in 0..<len(ref.frames[i].transforms) {
			animation.transforms[i][k] = ref.frames[i].transforms[k]
		}
	}

	return animation
} 

load_gltf_scene :: proc(ctx: ^Context, path: string) -> (scene_ptr: ^Scene, err: error.Error) {
	scene: Scene

	mark := mem.begin_arena_temp_memory(ctx.vk.tmp_arena)
	defer mem.end_arena_temp_memory(mark)

	glt := gltf.from_file(path, ctx.tmp_allocator) or_return
	gltf_scene := &glt.scenes["Scene"]

	scene.models = collection.new_vec(Model, u32(len(gltf_scene.nodes)), ctx.allocator) or_return

	for j in 0..<len(gltf_scene.nodes) {
		collection.vec_append(&scene.models, load_node(ctx, &glt, gltf_scene.nodes[j]) or_return) or_return
	}

	scene.animations = collection.new_vec(Scene_Animation, 1, ctx.allocator) or_return
	collection.vec_append(&scene.animations, load_animation(ctx, &glt, "First"))

	scene.bind_pose_transforms = collection.new_vec(Matrix, u32(len(glt.nodes)), ctx.allocator) or_return
	for i in 0..<len(glt.nodes) {
		collection.vec_append(&scene.bind_pose_transforms, linalg.MATRIX4F32_IDENTITY) or_return
	}

	// vk.add_bones(&ctx.vk, scene.bind_pose_transforms.data) or_return

	collection.vec_append(&ctx.scenes, scene) or_return

	return &ctx.scenes.data[ctx.scenes.len - 1], nil
}
