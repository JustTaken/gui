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
  ref: ^Scene_Animation,
}

Model :: struct {
  geometries: vector.Vector(u32),
  children: vector.Vector(u32),
}

Model_Instance :: struct {
  model: ^Model,
  instances: vector.Vector(^vulkan.Instance),
  children: vector.Vector(Model_Instance),
}

Scene :: struct {
  parent: ^Scenes,
  models: vector.Vector(u32),
}

Scene_Instance :: struct {
  scene: ^Scene,
  models: vector.Vector(Model_Instance),
  on_going: Maybe(On_Going_Animation),
}

Scenes :: struct {
  childs: map[string]Scene,
  animations: map[string]Scene_Animation,
  transforms: vector.Vector(Matrix),
  models: vector.Vector(Model),
  materials: vector.Vector(u32),
  transforms_offset: u32,
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

  vulkan.update_transforms(&ctx.vk, vector.data(&on_going.ref.transforms.data[on_going.last_frame]), instance.scene.parent.transforms_offset) or_return

  if finish {
    log.info("Finishing animation")
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

  if ref, ok := instance.scene.parent.animations[name]; ok {
    on_going.ref = &ref
  } else {
    log.error("Animation", name, "Not Found")
    return .NoAnimation
  }

  on_going.start = time
  on_going.last_frame = 0
  instance.on_going = on_going

  return nil
}

load_animations :: proc(ctx: ^Context, glt: ^gltf.Gltf) -> (animations: map[string]Scene_Animation, err: error.Error) {
  animations = make(map[string]Scene_Animation, glt.animations.len * 2, ctx.allocator)

  for i in 0..<glt.animations.len {
    animation: Scene_Animation

    ref := &glt.animations.data[i]
    log.info("Loading  Animation:", ref.name)

    animation.time_stamp = vector.new(f32, ref.frames.len, ctx.allocator) or_return
    animation.transforms = vector.new(vector.Vector(Matrix), ref.frames.len, ctx.allocator) or_return

    for i in 0..<ref.frames.len {
      vector.append(&animation.time_stamp, ref.frames.data[i].time) or_return
      transforms := vector.new(Matrix, ref.frames.data[i].transforms.len, ctx.allocator) or_return

      for k in 0..<ref.frames.data[i].transforms.len {
        vector.append(&transforms, ref.frames.data[i].transforms.data[k].compose) or_return
      }

      vector.append(&animation.transforms, transforms) or_return
    }

    animations[strings.clone(ref.name, ctx.allocator)] = animation
  }

  return animations, nil
} 

scene_instance_create :: proc(ctx: ^Context, scenes: ^Scenes, name: string, transform: Matrix, method: vulkan.Instance_Draw_Method) -> (instance: Scene_Instance, err: error.Error) {
  if scene, ok := scenes.childs[name]; ok {
    instance.scene = &scene
    instance.models = vector.new(Model_Instance, scene.models.len, ctx.allocator) or_return

    for i in 0..<scene.models.len {
      vector.append(&instance.models, model_instance_create(ctx, scenes, scene.models.data[i], transform, method) or_return) or_return
    }

    vulkan.add_transforms(&ctx.vk, vector.data(&scenes.transforms)) or_return

    return instance, nil
  }

  return instance, .InvalidScene
}

scene_instance_update :: proc(ctx: ^Context, instance: ^Scene_Instance, transform: Matrix) -> error.Error {
  for i in 0..<instance.models.len {
    for j in 0..<instance.models.data[i].instances.len {
      vulkan.instance_update(&ctx.vk, instance.models.data[i].instances.data[j], transform) or_return
    }
  }

  return nil
}

model_instance_create :: proc(ctx: ^Context, scenes: ^Scenes, model: u32, transform: Matrix, method: vulkan.Instance_Draw_Method) -> (instance: Model_Instance, err: error.Error) {
  instance.model = &scenes.models.data[model]

  instance.children = vector.new(Model_Instance, instance.model.children.len, ctx.allocator) or_return
  for i in 0..<instance.model.children.len {
    vector.append(&instance.children, model_instance_create(ctx, scenes, instance.model.children.data[i], transform, method) or_return) or_return
  }

  instance.instances = vector.new(^vulkan.Instance, instance.model.geometries.len, ctx.allocator) or_return
  for i in 0..<instance.model.geometries.len {
      vector.append(&instance.instances, vulkan.geometry_instance_add(&ctx.vk, instance.model.geometries.data[i], transform, model, method) or_return) or_return
  }

  return instance, nil
}

load_mesh :: proc(ctx: ^Context, glt: ^gltf.Gltf, scenes: ^Scenes, node: u32, max: u32) -> (geometries: vector.Vector(u32), err: error.Error) {
  if glt.nodes.data[node].skin != nil {
    geometries = load_boned_mesh(ctx, glt, scenes, node, max) or_return
  } else {
    geometries = load_unboned_mesh(ctx, glt, scenes, node, max) or_return
  }

  return geometries, nil
}

load_unboned_mesh :: proc(ctx: ^Context, glt: ^gltf.Gltf, scenes: ^Scenes, node: u32, max: u32) -> (geometries: vector.Vector(u32), err: error.Error) {
  Vertex :: struct {
    position: [3]f32,
    normal: [3]f32,
    texture: [2]f32,
  }

  mesh := &glt.meshes.data[glt.nodes.data[node].mesh.?]
  transform := glt.nodes.data[node].transform.compose

  geometries = vector.new(u32, mesh.primitives.len, ctx.allocator) or_return

  for p in 0..<mesh.primitives.len {
    primitive := &mesh.primitives.data[p]

    positions := primitive.accessors[.Position]
    normals := primitive.accessors[.Normal]
    textures := primitive.accessors[.Texture0]
    indices := primitive.indices

    assert(positions.component_kind == .F32 && positions.component_count == 3)
    assert(normals.component_kind == .F32 && normals.component_count == 3)
    assert(textures.component_kind == .F32 && textures.component_count == 2)
    assert(indices.component_kind == .U16 && indices.component_count == 1)

    assert(size_of(Vertex) == (size_of(f32) * positions.component_count) + (size_of(f32) * normals.component_count) + (size_of(f32) * textures.component_count))

    count := positions.count

    vertices := vector.new(Vertex, count, ctx.tmp_allocator) or_return

    pos := cast([^][3]f32)raw_data(positions.bytes)
    norms := cast([^][3]f32)raw_data(normals.bytes)
    texts := cast([^][2]f32)raw_data(textures.bytes)

    for i in 0..<count {
      vertex := vector.one(&vertices) or_return

      vertex.position = pos[i]
      vertex.normal = norms[i]
      vertex.texture = texts[i]
    }

    material: Maybe(u32) = nil
    if primitive.material != nil {
      material = scenes.materials.data[primitive.material.?]
    }

    ind := (cast([^]u16)raw_data(indices.bytes))[0:indices.count]
    geometry := vulkan.geometry_create(Vertex, &ctx.vk, vector.data(&vertices), ind, transform, material, .Unboned) or_return
    vector.append(&geometries, geometry) or_return
  }

  return geometries, nil
}

load_boned_mesh :: proc(ctx: ^Context, glt: ^gltf.Gltf, scenes: ^Scenes, node: u32, max: u32) -> (geometries: vector.Vector(u32), err: error.Error) {
  Vertex :: struct {
    position: [3]f32,
    normal: [3]f32,
    texture: [2]f32,
    weight: [4]f32,
    joint: [4]u32,
  }

  mesh := &glt.meshes.data[glt.nodes.data[node].mesh.?]
  transform := glt.nodes.data[node].transform.compose

  geometries = vector.new(u32, mesh.primitives.len, ctx.allocator) or_return

  for p in 0..<mesh.primitives.len {
    primitive := &mesh.primitives.data[p]

    positions := primitive.accessors[.Position]
    normals := primitive.accessors[.Normal]
    textures := primitive.accessors[.Texture0]
    weights := primitive.accessors[.Weight0]
    joints := primitive.accessors[.Joint0]
    indices := primitive.indices

    assert(positions.component_kind == .F32 && positions.component_count == 3)
    assert(normals.component_kind == .F32 && normals.component_count == 3)
    assert(textures.component_kind == .F32 && textures.component_count == 2)
    assert(weights.component_kind == .F32 && weights.component_count == 4)
    assert(joints.component_kind == .U8 && joints.component_count == 4)
    assert(indices.component_kind == .U16 && indices.component_count == 1)

    assert(size_of(Vertex) == (size_of(u32) * joints.component_count) + (size_of(f32) * weights.component_count) + (size_of(f32) * positions.component_count) + (size_of(f32) * normals.component_count) + (size_of(f32) * textures.component_count))

    count := positions.count

    vertices := vector.new(Vertex, count, ctx.tmp_allocator) or_return

    pos := cast([^][3]f32)raw_data(positions.bytes)
    norms := cast([^][3]f32)raw_data(normals.bytes)
    texts := cast([^][2]f32)raw_data(textures.bytes)
    weigh := cast([^][4]f32)raw_data(weights.bytes)
    joint := cast([^][4]u8)raw_data(joints.bytes)

    for i in 0..<count {
      vertex := vector.one(&vertices) or_return

      vertex.position = pos[i]
      vertex.normal = norms[i]
      vertex.texture = texts[i]
      vertex.weight = weigh[i]
      vertex.joint = {u32(joint[i][0]), u32(joint[i][1]), u32(joint[i][2]), u32(joint[i][3])}
    }

    material: Maybe(u32) = nil
    if primitive.material != nil {
      material = scenes.materials.data[primitive.material.?]
    }

    ind := (cast([^]u16)raw_data(indices.bytes))[0:indices.count]
    geometry := vulkan.geometry_create(Vertex, &ctx.vk, vector.data(&vertices), ind, transform, material, .Boned) or_return
    vector.append(&geometries, geometry) or_return
  }

  return geometries, nil
}

load_node :: proc(ctx: ^Context, glt: ^gltf.Gltf, scenes: ^Scenes, node: u32, max: u32) -> error.Error {
  model := vector.one(&scenes.models) or_return
  model.children = vector.new(u32, glt.nodes.data[node].children.len, ctx.allocator) or_return

  for i in 0..<glt.nodes.data[node].children.len {
    vector.append(&model.children, glt.nodes.data[node].children.data[i]) or_return
  }

  if glt.nodes.data[node].mesh != nil {
    model.geometries = load_mesh(ctx, glt, scenes, node, max) or_return
  }

  return nil
}

load_material :: proc(ctx: ^Context, glt: ^gltf.Gltf, scenes: ^Scenes, index: u32) -> error.Error {
  vector.append(&scenes.materials, vulkan.material_create(&ctx.vk, glt.materials.data[index].color) or_return) or_return

  return nil
}

load_gltf_scene :: proc(ctx: ^Context, scenes: ^Scenes, glt: gltf.Gltf, index: u32) -> error.Error {
  scene: Scene

  scene.models = vector.new(u32, glt.scenes.data[index].nodes.len, ctx.allocator) or_return
  scene.parent = scenes

  for j in 0..<glt.scenes.data[index].nodes.len {
    vector.append(&scene.models, glt.scenes.data[index].nodes.data[j]) or_return
  }

  scenes.childs[glt.scenes.data[index].name] = scene

  return nil
}

load_gltf_scenes :: proc(ctx: ^Context, path: string, max: u32) -> (scenes: Scenes, err: error.Error) {
  mark := mem.begin_arena_temp_memory(&ctx.tmp_arena)
  defer mem.end_arena_temp_memory(mark)

  glt := gltf.from_file(path, ctx.tmp_allocator) or_return

  scenes.models = vector.new(Model, glt.nodes.len, ctx.allocator) or_return
  scenes.materials =vector.new(u32, glt.materials.len, ctx.allocator) or_return
  scenes.childs = make(map[string]Scene, (glt.scenes.len * 3) / 2, ctx.allocator)
  scenes.transforms = vector.new(Matrix, glt.nodes.len, ctx.allocator) or_return

  for i in 0..<glt.materials.len {
    load_material(ctx, &glt, &scenes, i) or_return
  }

  for i in 0..<glt.nodes.len {
    load_node(ctx, &glt, &scenes, i, max) or_return
    vector.append(&scenes.transforms, linalg.MATRIX4F32_IDENTITY) or_return
  }

  scenes.animations = load_animations(ctx, &glt) or_return

  for i in 0..<glt.scenes.len {
    load_gltf_scene(ctx, &scenes, glt, i) or_return
  }


  return scenes, nil
}

@test
main_test :: proc(t: ^testing.T) {
  glt, err := gltf.from_file("assets/translation.gltf", context.allocator)
  testing.expect(t, err == nil)
}
