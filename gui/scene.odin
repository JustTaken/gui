package main

import "collection/gltf"
import vk "vulkan"
import "error"
import "core:mem"
import "collection"
import "core:log"
import "core:math/linalg"
import "core:strings"
import "core:testing"

Matrix :: matrix[4, 4]f32

Scene_Animation :: struct {
  time_stamp: []f32,
  transforms: [][]Matrix,
}

On_Going_Animation :: struct {
  start: i64,
  last_frame: u32,
  ref: Scene_Animation,
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
  all_models: collection.Vector(Model),
  models: collection.Vector(^Model),
  animations: map[string]Scene_Animation,
  transforms_offset: u32,
}

Model :: struct {
  geometries: collection.Vector(^vk.Geometry),
  children: collection.Vector(^Model),
  bones: collection.Vector(Matrix),
}

next_scene_animation_frame :: proc(ctx: ^Context, instance: ^Scene_Instance, name: string) -> error.Error {
  if instance.on_going == nil {
    play_scene_animation(instance, name, 0)
    return nil
  }

  on_going := &instance.on_going.?

  if on_going.last_frame >= u32(len(on_going.ref.time_stamp)) {
    instance.on_going = nil
    return nil
  }

  vk.update_transforms(&ctx.vk, on_going.ref.transforms[on_going.last_frame], instance.scene.transforms_offset) or_return
  on_going.last_frame += 1;

  return nil
}

prev_scene_animation_frame :: proc(ctx: ^Context, instance: ^Scene_Instance, name: string) -> error.Error {
  if instance.on_going == nil {
    play_scene_animation(instance, name, 0)
    return nil
  }

  on_going := &instance.on_going.?

  if on_going.last_frame == 0 {
    instance.on_going = nil
    return nil
  }

  on_going.last_frame -= 1;
  vk.update_transforms(&ctx.vk, on_going.ref.transforms[on_going.last_frame], instance.scene.transforms_offset) or_return

  return nil
}

tick_scene_animation :: proc(ctx: ^Context, instance: ^Scene_Instance, time: i64) -> error.Error {
  if instance.on_going == nil do return nil
  on_going := &instance.on_going.?

  delta := time - on_going.start

  tick := f32(f64(delta) / 1000000000.0)
  previous_last := on_going.last_frame
  finish := false

  for tick > on_going.ref.time_stamp[on_going.last_frame] {
    on_going.last_frame += 1

    if on_going.last_frame + 1 >= u32(len(on_going.ref.time_stamp)) {
      finish = true
      break
    }
  }

  if previous_last == on_going.last_frame do return nil

  vk.update_transforms(&ctx.vk, on_going.ref.transforms[on_going.last_frame], instance.scene.transforms_offset) or_return

  if finish {
    log.info("Finishing animation")
    // instance.on_going = nil
    on_going.last_frame = 0
    on_going.start = time
  }

  return nil
}

play_scene_animation :: proc(instance: ^Scene_Instance, name: string, time: i64) -> error.Error {
  if instance.on_going != nil {
    instance.on_going = nil
    return nil
  }

  log.info("Playing animation", name, time)

  on_going: On_Going_Animation

  if ref, ok := instance.scene.animations[name]; ok {
    on_going.ref = ref
  } else {
    log.error("Animation", name, "Not Found")
    return .NoAnimation
  }

  on_going.start = time
  on_going.last_frame = 0
  instance.on_going = on_going

  return nil
}

load_animations :: proc(ctx: ^Context, glt: ^gltf.Gltf, scene: ^Scene) {
  scene.animations = make(map[string]Scene_Animation, len(glt.animations) * 2, ctx.allocator)

  for i in 0..<len(glt.animations) {
    animation: Scene_Animation

    ref := &glt.animations[i]
    log.info("Loading  Animation:", ref.name)

    animation.time_stamp = make([]f32, len(ref.frames), ctx.allocator)
    animation.transforms = make([][]Matrix, len(ref.frames), ctx.allocator)

    for i in 0..<len(ref.frames) {
      animation.time_stamp[i] = ref.frames[i].time
      animation.transforms[i] = make([]Matrix, len(ref.frames[i].transforms), ctx.allocator)

      for k in 0..<len(ref.frames[i].transforms) {
        animation.transforms[i][k] = ref.frames[i].transforms[k].compose
      }
    }

    scene.animations[strings.clone(ref.name, ctx.allocator)] = animation
  }
} 

scene_instance_create :: proc(ctx: ^Context, scene: ^Scene, transform: Matrix) -> (instance: Scene_Instance, err: error.Error) {
  instance.scene = scene
  instance.models = collection.new_vec(Model_Instance, scene.models.len, ctx.allocator) or_return

  for i in 0..<scene.models.len {
    collection.vec_append(&instance.models, model_instance_create(ctx, scene.models.data[i], transform) or_return) or_return
  }

  return instance, nil
}

model_instance_create :: proc(ctx: ^Context, model: ^Model, transform: Matrix) -> (instance: Model_Instance, err: error.Error) {
  instance.model = model

  instance.bones = collection.new_vec(Scene_Instance, model.bones.len, ctx.allocator) or_return
  //for i in 0..<model.bones.len {
    //collection.vec_append(&instance.bones, scene_instance_create(ctx, ctx.bone, transform * model.bones.data[i]) or_return) or_return
  //}

  instance.children = collection.new_vec(Model_Instance, model.children.len, ctx.allocator) or_return
  for i in 0..<model.children.len {
    collection.vec_append(&instance.children, model_instance_create(ctx, model.children.data[i], transform) or_return) or_return
  }

  instance.instances = collection.new_vec(^vk.Instance, model.geometries.len, ctx.allocator) or_return
  for i in 0..<model.geometries.len {
      collection.vec_append(&instance.instances, vk.geometry_instance_add(&ctx.vk, model.geometries.data[i], transform) or_return) or_return
  }

  return instance, nil
}

load_mesh :: proc(ctx: ^Context, glt: ^gltf.Gltf, node: u32, max: u32) -> (geometries: collection.Vector(^vk.Geometry), err: error.Error) {
  if glt.nodes[node].skin != nil {
    geometries = load_boned_mesh(ctx, glt, node, max) or_return
  } else {
    geometries = load_unboned_mesh(ctx, glt, node, max) or_return
  }

  return geometries, nil
}

load_unboned_mesh :: proc(ctx: ^Context, glt: ^gltf.Gltf, node: u32, max: u32) -> (geometries: collection.Vector(^vk.Geometry), err: error.Error) {
  Vertex :: struct {
    position: [3]f32,
    normal: [3]f32,
    texture: [2]f32,
  }

  mesh := &glt.meshes[glt.nodes[node].mesh.?]
  transform := glt.nodes[node].transform.compose

  geometries = collection.new_vec(^vk.Geometry, u32(len(mesh.primitives)), ctx.allocator) or_return

  for primitive in mesh.primitives {
    positions := primitive.accessors[.Position]
    normals := primitive.accessors[.Normal]
    textures := primitive.accessors[.Texture0]

    assert(positions.component_kind == .F32 && positions.component_count == 3)
    assert(normals.component_kind == .F32 && normals.component_count == 3)
    assert(textures.component_kind == .F32 && textures.component_count == 2)

    assert(size_of(Vertex) == (size_of(f32) * positions.component_count) + (size_of(f32) * normals.component_count) + (size_of(f32) * textures.component_count))

    count := positions.count

    indices := primitive.indices
    bytes := make([]u8, size_of(Vertex) * count, ctx.tmp_allocator)

    pos := cast([^][3]f32)raw_data(positions.bytes)
    norms := cast([^][3]f32)raw_data(normals.bytes)
    texts := cast([^][2]f32)raw_data(textures.bytes)

    vertices := cast([^]Vertex)raw_data(bytes)

    for i in 0..<count {
      vertices[i].position = pos[i]
      vertices[i].normal = norms[i]
      vertices[i].texture = texts[i]
    }

    collection.vec_append(&geometries, vk.geometry_create(&ctx.vk, bytes, size_of(Vertex), count, indices.bytes, gltf.get_accessor_size(indices), indices.count, max, transform, false) or_return) or_return
  }

  return geometries, nil
}

load_boned_mesh :: proc(ctx: ^Context, glt: ^gltf.Gltf, node: u32, max: u32) -> (geometries: collection.Vector(^vk.Geometry), err: error.Error) {
  Vertex :: struct {
    position: [3]f32,
    normal: [3]f32,
    texture: [2]f32,
    weight: [4]f32,
    joint: [4]u32,
  }

  mesh := &glt.meshes[glt.nodes[node].mesh.?]
  transform := glt.nodes[node].transform.compose

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
    bytes := make([]u8, size_of(Vertex) * count, ctx.tmp_allocator)

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

    collection.vec_append(&geometries, vk.geometry_create(&ctx.vk, bytes, size_of(Vertex), count, indices.bytes, gltf.get_accessor_size(indices), indices.count, max, transform, true) or_return) or_return
  }

  return geometries, nil
}

load_node :: proc(ctx: ^Context, glt: ^gltf.Gltf, scene: ^Scene, node: u32, max: u32) -> error.Error {
  model := collection.vec_one(&scene.all_models) or_return
  model.children = collection.new_vec(^Model, u32(len(glt.nodes[node].children)), ctx.allocator) or_return

  if glt.nodes[node].skin != nil {
    skin := &glt.skins[glt.nodes[node].skin.?]
    model.bones = collection.new_vec(Matrix, u32(len(skin.joints)), ctx.allocator) or_return

    for joint in skin.joints {
      collection.vec_append(&model.bones, glt.nodes[joint].transform.compose) or_return
    }
  }

  for child in glt.nodes[node].children {
    collection.vec_append(&model.children, &scene.all_models.data[child]) or_return
  }

  if glt.nodes[node].mesh != nil {
    model.geometries = load_mesh(ctx, glt, node, max) or_return
  }

  return nil
}

load_gltf_scene :: proc(ctx: ^Context, path: string, max: u32) -> (scene: ^Scene, err: error.Error) {
  scene = collection.vec_one(&ctx.scenes) or_return

  mark := mem.begin_arena_temp_memory(&ctx.tmp_arena)
  defer mem.end_arena_temp_memory(mark)

  glt := gltf.from_file(path, ctx.tmp_allocator) or_return
  gltf_scene := &glt.scenes["Scene"]


  scene.all_models = collection.new_vec(Model, u32(len(glt.nodes)), ctx.allocator) or_return
  scene.models = collection.new_vec(^Model, u32(len(gltf_scene.nodes)), ctx.allocator) or_return

  for j in 0..<len(glt.nodes) {
    load_node(ctx, &glt, scene, u32(j), max) or_return
  }

  for j in 0..<len(gltf_scene.nodes) {
    collection.vec_append(&scene.models, &scene.all_models.data[gltf_scene.nodes[j]]) or_return
  }

  load_animations(ctx, &glt, scene)

  bones := make([]Matrix, len(glt.nodes), ctx.tmp_allocator)

  for n in 0..<len(glt.nodes) {
    bones[n] = linalg.MATRIX4F32_IDENTITY
  }

  scene.transforms_offset = vk.add_transforms(&ctx.vk, bones) or_return

  return scene, nil
}

@test
main_test :: proc(t: ^testing.T) {
  ctx: Context
  err: error.Error

  err = init_memory(&ctx, 1024 * 1024 * 2, 2)
  testing.expect(t, err == nil)

  ctx.scenes, err = collection.new_vec(Scene, 20, ctx.allocator)
  testing.expect(t, err == nil)

  ctx.cube, err = load_gltf_scene(&ctx, "assets/translation.gltf", 1)
  testing.expect(t, err == nil)
}
