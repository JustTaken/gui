package main

import "lib:collection/gltf"
import "lib:collection/vector"
import "lib:error"
import "lib:vulkan"
import "core:mem"
import "core:log"
import "core:math/linalg"
import "core:strings"
import "core:testing"

Matrix :: matrix[4, 4]f32

Scene_Animation :: struct {
  time_stamp: vector.Vector(f32),
  transforms: vector.Vector(vector.Vector(Matrix)),
}

On_Going_Animation :: struct {
  start: i64,
  last_frame: u32,
  ref: Scene_Animation,
}

Model_Instance :: struct {
  model: ^Model,
  instances: vector.Vector(^vulkan.Instance),
  bones: vector.Vector(Scene_Instance),
  children: vector.Vector(Model_Instance),
}

Scene_Instance :: struct {
  scene: ^Scene,
  models: vector.Vector(Model_Instance),
  on_going: Maybe(On_Going_Animation),
}

Scene :: struct {
  all_models: vector.Vector(Model),
  models: vector.Vector(^Model),
  animations: map[string]Scene_Animation,
  transforms_offset: u32,
}

Model :: struct {
  geometries: vector.Vector(^vulkan.Geometry),
  children: vector.Vector(^Model),
  bones: vector.Vector(Matrix),
}

// next_scene_animation_frame :: proc(ctx: ^Context, instance: ^Scene_Instance, name: string) -> error.Error {
//   if instance.on_going == nil {
//     play_scene_animation(instance, name, 0)
//     return nil
//   }

//   on_going := &instance.on_going.?

//   if on_going.last_frame >= on_going.ref.time_stamp.len {
//     instance.on_going = nil
//     return nil
//   }

//   vulkan.update_transforms(&ctx.vulkan, on_going.ref.transforms[on_going.last_frame], instance.scene.transforms_offset) or_return
//   on_going.last_frame += 1;

//   return nil
// }

// prev_scene_animation_frame :: proc(ctx: ^Context, instance: ^Scene_Instance, name: string) -> error.Error {
//   if instance.on_going == nil {
//     play_scene_animation(instance, name, 0)
//     return nil
//   }

//   on_going := &instance.on_going.?

//   if on_going.last_frame == 0 {
//     instance.on_going = nil
//     return nil
//   }

//   on_going.last_frame -= 1;
//   vulkan.update_transforms(&ctx.vulkan, on_going.ref.transforms[on_going.last_frame].data, instance.scene.transforms_offset) or_return

//   return nil
// }

tick_scene_animation :: proc(ctx: ^Context, instance: ^Scene_Instance, time: i64) -> error.Error {
  if instance.on_going == nil do return nil
  on_going := &instance.on_going.?

  delta := time - on_going.start

  tick := f32(f64(delta) / 1000000000.0)
  previous_last := on_going.last_frame
  finish := false

  for tick > on_going.ref.time_stamp.data[on_going.last_frame] {
    on_going.last_frame += 1

    if on_going.last_frame + 1 >= on_going.ref.time_stamp.len {
      finish = true
      break
    }
  }

  if previous_last == on_going.last_frame do return nil

  vulkan.update_transforms(&ctx.vk, vector.data(&on_going.ref.transforms.data[on_going.last_frame]), instance.scene.transforms_offset) or_return

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

load_animations :: proc(ctx: ^Context, glt: ^gltf.Gltf, scene: ^Scene) -> error.Error {
  scene.animations = make(map[string]Scene_Animation, glt.animations.len * 2, ctx.allocator)

  for i in 0..<glt.animations.len {
    animation: Scene_Animation

    ref := &glt.animations.data[i]
    log.info("Loading  Animation:", ref.name)

    animation.time_stamp = vector.new(f32, ref.frames.len, ctx.allocator) or_return
    animation.transforms = vector.new(vector.Vector(Matrix), ref.frames.len, ctx.allocator) or_return

    for i in 0..<ref.frames.len {
      vector.append(&animation.time_stamp, ref.frames.data[i].time) or_return
      transforms := vector.new(Matrix, ref.frames.data[i].transforms.len, ctx.allocator) or_return

      // animation.transforms[i] = make([]Matrix, len(ref.frames[i].transforms), ctx.allocator)

      for k in 0..<ref.frames.data[i].transforms.len {
        vector.append(&transforms, ref.frames.data[i].transforms.data[k].compose) or_return
      }

      vector.append(&animation.transforms, transforms) or_return
    }

    scene.animations[strings.clone(ref.name, ctx.allocator)] = animation
  }

  return nil
} 

scene_instance_create :: proc(ctx: ^Context, scene: ^Scene, transform: Matrix) -> (instance: Scene_Instance, err: error.Error) {
  instance.scene = scene
  instance.models = vector.new(Model_Instance, scene.models.len, ctx.allocator) or_return

  for i in 0..<scene.models.len {
    vector.append(&instance.models, model_instance_create(ctx, scene.models.data[i], transform) or_return) or_return
  }

  return instance, nil
}

model_instance_create :: proc(ctx: ^Context, model: ^Model, transform: Matrix) -> (instance: Model_Instance, err: error.Error) {
  instance.model = model

  instance.bones = vector.new(Scene_Instance, model.bones.len, ctx.allocator) or_return
  //for i in 0..<model.bones.len {
    //collection.append(&instance.bones, scene_instance_create(ctx, ctx.bone, transform * model.bones.data[i]) or_return) or_return
  //}

  instance.children = vector.new(Model_Instance, model.children.len, ctx.allocator) or_return
  for i in 0..<model.children.len {
    vector.append(&instance.children, model_instance_create(ctx, model.children.data[i], transform) or_return) or_return
  }

  instance.instances = vector.new(^vulkan.Instance, model.geometries.len, ctx.allocator) or_return
  for i in 0..<model.geometries.len {
      vector.append(&instance.instances, vulkan.geometry_instance_add(&ctx.vk, model.geometries.data[i], transform) or_return) or_return
  }

  return instance, nil
}

load_mesh :: proc(ctx: ^Context, glt: ^gltf.Gltf, node: u32, max: u32) -> (geometries: vector.Vector(^vulkan.Geometry), err: error.Error) {
  if glt.nodes.data[node].skin != nil {
    geometries = load_boned_mesh(ctx, glt, node, max) or_return
  } else {
    geometries = load_unboned_mesh(ctx, glt, node, max) or_return
  }

  return geometries, nil
}

load_unboned_mesh :: proc(ctx: ^Context, glt: ^gltf.Gltf, node: u32, max: u32) -> (geometries: vector.Vector(^vulkan.Geometry), err: error.Error) {
  Vertex :: struct {
    position: [3]f32,
    normal: [3]f32,
    texture: [2]f32,
  }

  mesh := &glt.meshes.data[glt.nodes.data[node].mesh.?]
  transform := glt.nodes.data[node].transform.compose

  geometries = vector.new(^vulkan.Geometry, mesh.primitives.len, ctx.allocator) or_return

  for p in 0..<mesh.primitives.len {
    positions := mesh.primitives.data[p].accessors[.Position]
    normals := mesh.primitives.data[p].accessors[.Normal]
    textures := mesh.primitives.data[p].accessors[.Texture0]
    indices := mesh.primitives.data[p].indices

    assert(positions.component_kind == .F32 && positions.component_count == 3)
    assert(normals.component_kind == .F32 && normals.component_count == 3)
    assert(textures.component_kind == .F32 && textures.component_count == 2)

    assert(size_of(Vertex) == (size_of(f32) * positions.component_count) + (size_of(f32) * normals.component_count) + (size_of(f32) * textures.component_count))

    count := positions.count

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

    vector.append(&geometries, vulkan.geometry_create(&ctx.vk, bytes, size_of(Vertex), count, indices.bytes, gltf.get_accessor_size(indices), indices.count, max, transform, false) or_return) or_return
  }

  return geometries, nil
}

load_boned_mesh :: proc(ctx: ^Context, glt: ^gltf.Gltf, node: u32, max: u32) -> (geometries: vector.Vector(^vulkan.Geometry), err: error.Error) {
  Vertex :: struct {
    position: [3]f32,
    normal: [3]f32,
    texture: [2]f32,
    weight: [4]f32,
    joint: [4]u32,
  }

  mesh := &glt.meshes.data[glt.nodes.data[node].mesh.?]
  transform := glt.nodes.data[node].transform.compose

  geometries = vector.new(^vulkan.Geometry, mesh.primitives.len, ctx.allocator) or_return

  for p in 0..<mesh.primitives.len {
    positions := mesh.primitives.data[p].accessors[.Position]
    normals := mesh.primitives.data[p].accessors[.Normal]
    textures := mesh.primitives.data[p].accessors[.Texture0]
    weights := mesh.primitives.data[p].accessors[.Weight0]
    joints := mesh.primitives.data[p].accessors[.Joint0]
    indices := mesh.primitives.data[p].indices

    assert(positions.component_kind == .F32 && positions.component_count == 3)
    assert(normals.component_kind == .F32 && normals.component_count == 3)
    assert(textures.component_kind == .F32 && textures.component_count == 2)
    assert(weights.component_kind == .F32 && weights.component_count == 4)
    assert(joints.component_kind == .U8 && joints.component_count == 4)

    assert(size_of(Vertex) == (size_of(u32) * joints.component_count) + (size_of(f32) * weights.component_count) + (size_of(f32) * positions.component_count) + (size_of(f32) * normals.component_count) + (size_of(f32) * textures.component_count))

    count := positions.count

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

    vector.append(&geometries, vulkan.geometry_create(&ctx.vk, bytes, size_of(Vertex), count, indices.bytes, gltf.get_accessor_size(indices), indices.count, max, transform, true) or_return) or_return
  }

  return geometries, nil
}

load_node :: proc(ctx: ^Context, glt: ^gltf.Gltf, scene: ^Scene, node: u32, max: u32) -> error.Error {
  model := vector.one(&scene.all_models) or_return
  model.children = vector.new(^Model, glt.nodes.data[node].children.len, ctx.allocator) or_return

  if glt.nodes.data[node].skin != nil {
    skin := &glt.skins.data[glt.nodes.data[node].skin.?]
    model.bones = vector.new(Matrix, skin.joints.len, ctx.allocator) or_return

    for i in 0..<skin.joints.len {
      vector.append(&model.bones, glt.nodes.data[skin.joints.data[i]].transform.compose) or_return
    }
  }

  for i in 0..<glt.nodes.data[node].children.len {
    vector.append(&model.children, &scene.all_models.data[glt.nodes.data[node].children.data[i]]) or_return
  }

  if glt.nodes.data[node].mesh != nil {
    model.geometries = load_mesh(ctx, glt, node, max) or_return
  }

  return nil
}

load_gltf_scene :: proc(ctx: ^Context, path: string, max: u32) -> (scene: ^Scene, err: error.Error) {
  scene = vector.one(&ctx.scenes) or_return

  mark := mem.begin_arena_temp_memory(&ctx.tmp_arena)
  defer mem.end_arena_temp_memory(mark)

  glt := gltf.from_file(path, ctx.tmp_allocator) or_return
  gltf_scene := &glt.scenes["Scene"]


  scene.all_models = vector.new(Model, glt.nodes.len, ctx.allocator) or_return
  scene.models = vector.new(^Model, gltf_scene.nodes.len, ctx.allocator) or_return

  for j in 0..<glt.nodes.len {
    load_node(ctx, &glt, scene, j, max) or_return
  }

  for j in 0..<gltf_scene.nodes.len {
    vector.append(&scene.models, &scene.all_models.data[gltf_scene.nodes.data[j]]) or_return
  }

  load_animations(ctx, &glt, scene)

  bones := vector.new(Matrix, glt.nodes.len, ctx.tmp_allocator) or_return

  for n in 0..<glt.nodes.len {
    vector.append(&bones, linalg.MATRIX4F32_IDENTITY) or_return
  }

  scene.transforms_offset = vulkan.add_transforms(&ctx.vk, vector.data(&bones)) or_return

  return scene, nil
}

@test
main_test :: proc(t: ^testing.T) {
  glt, err := gltf.from_file("assets/translation.gltf", context.allocator)
  testing.expect(t, err == nil)
}
