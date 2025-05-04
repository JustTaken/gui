package collection

import "base:runtime"
import "core:os"
import "core:log"
import "core:encoding/json"
import "core:path/filepath"
import "core:math/linalg"
import "core:fmt"
import "core:strings"

Matrix :: matrix[4, 4]f32

Gltf_Buffer :: struct {
  fd:  os.Handle,
  len: u32,
}

Gltf_Asset :: struct {
  generator: string,
  version: string,
}

Gltf_Animation_Interpolation :: enum {
  Linear,
  Step,
  CubicSpline,
}

Gltf_Animation_Sampler_Obj :: struct {
  time: f32,
  transform: Matrix,
}

Gltf_Animation_Sampler :: struct {
  interpolation: Gltf_Animation_Interpolation,
  objs: []Gltf_Animation_Sampler_Obj,
  // input: Gltf_Attribute,
  // output: Gltf_Attribute,
}

Gltf_Animation_Path :: enum {
  Translation,
  Rotation,
  Scale,
  Weights,
}

Gltf_Animation_Target :: struct {
  node: u32,
  path: Gltf_Animation_Path,
}

Gltf_Animation_Channel :: struct {
  sampler: Gltf_Animation_Sampler,
  target: Gltf_Animation_Target,
}

Gltf_Animation_Frame :: struct {
  time: f32,
  transforms: []Matrix,
}

Gltf_Animation :: struct {
  channels: []Gltf_Animation_Channel,
  nodes: []u32,
  frames: []Gltf_Animation_Frame,
}

Gltf_Attribute_Kind :: enum {
  Position,
  Normal,
  Texture0,
  Texture1,
  Color0,
  Joint0,
  Weight0,
}

Gltf_Attribute_Component :: enum {
  F32,
  U16
}

Gltf_Attribute :: struct {
  component: Gltf_Attribute_Component,
  component_size: u32,

  bytes: []u8,
  count: u32,
}

Gltf_Target :: []Gltf_Attribute

Gltf_Material_Metallic_Roughness :: struct {
  base_color_factor: []f64,
}

Gltf_Material :: struct {
  name: string,
  double_sided: bool,
  metallic_roughness: Gltf_Material_Metallic_Roughness,
  metallic_factor: f64,
  roughness_factor: f64,
}

Gltf_Mesh_Primitive :: struct {
  attributes: [Gltf_Attribute_Kind]Maybe(Gltf_Attribute),
  indices: Maybe(Gltf_Attribute),
  targets: []Gltf_Target,
  material: Gltf_Material,
}

Gltf_Mesh :: struct {
  name: string,
  primitives: []Gltf_Mesh_Primitive,
}

Gltf_Node :: struct {
  name: string,
  mesh: Gltf_Mesh,
  transform: matrix[4, 4]f32,
}

Gltf_Scene :: struct {
  nodes: []Gltf_Node,
}

Gltf_Context :: struct {
  obj: json.Object,

  raw_accessors: json.Array,
  raw_meshes: json.Array,
  raw_buffer_views: json.Array,
  raw_nodes: json.Array,
  raw_materials: json.Array,

  nodes: []Gltf_Node,
  buffers: []Gltf_Buffer,
  allocator: runtime.Allocator,
  tmp_allocator: runtime.Allocator,
}

Gltf :: struct {
  asset: Gltf_Asset,
  scenes: map[string]Gltf_Scene,
  animations: map[string]Gltf_Animation,
}

gltf_from_file :: proc(path: string, allocator: runtime.Allocator, tmp_allocator: runtime.Allocator) -> (gltf: Gltf, err: Error) {
  value: json.Value
  j_err: json.Error
  bytes: []u8
  ok: bool
  os_err: os.Error

  log.info("Parsing", path)

  ctx: Gltf_Context
  ctx.allocator = allocator
  ctx.tmp_allocator = tmp_allocator

  if bytes, ok = os.read_entire_file(path); !ok do return gltf, .FileNotFound
  if value, j_err = json.parse(bytes, allocator = ctx.tmp_allocator); j_err != nil do return gltf, .GltfLoadFailed
  dir := filepath.dir(path, ctx.tmp_allocator)

  ctx.obj = value.(json.Object)

  ctx.raw_accessors = ctx.obj["accessors"].(json.Array)
  ctx.raw_buffer_views = ctx.obj["bufferViews"].(json.Array)
  ctx.raw_meshes = ctx.obj["meshes"].(json.Array)
  ctx.raw_nodes = ctx.obj["nodes"].(json.Array)

  if materials, ok := ctx.obj["materials"]; ok {
    ctx.raw_materials = materials.(json.Array)
  }

  raw_buffers := ctx.obj["buffers"].(json.Array)
  ctx.buffers = make([]Gltf_Buffer, len(raw_buffers), ctx.tmp_allocator)

  for i in 0 ..< len(raw_buffers) {
    buffer := &ctx.buffers[i]
    raw := &raw_buffers[i].(json.Object)

    uri_array := [?]string{dir, raw["uri"].(string)}
    uri := filepath.join(uri_array[:], ctx.tmp_allocator)

    if buffer.fd, os_err = os.open(uri); os_err != nil do return gltf, .FileNotFound
    buffer.len = u32(raw["byteLength"].(f64))
  }


  gltf.asset = parse_asset(&ctx) or_return
  ctx.nodes = parse_nodes(&ctx) or_return
  gltf.scenes = parse_scenes(&ctx) or_return

  if gltf.animations, err = parse_animations(&ctx); err != nil {
    log.info("No animations found")
  }

  for buffer in ctx.buffers {
    if os.close(buffer.fd) != nil do return gltf, .FileNotFound
  }

  return gltf, nil
}

Vertex_Data :: struct {
  bytes: []u8,
  size: u32,
  count: u32,
}

get_vertex_data :: proc(attributes: []Gltf_Attribute, allocator: runtime.Allocator) -> Vertex_Data {
  data: Vertex_Data
  data.size = 0
  data.count = 0

  count: u32 = 0

  sizes := make([]u32, len(attributes), allocator)

  for i in 0..<len(attributes) {
    sizes[i] = attributes[i].component_size * get_attribute_component_size(attributes[i].component)
    count += sizes[i] * attributes[i].count
    data.count = attributes[i].count
    data.size += sizes[i]
  }

  data.bytes = make([]u8, count, allocator)

  l: u32 = 0
  for i in 0..<data.count {
    for k in 0..<len(attributes) {
      start := i * sizes[k]
      end := sizes[k] + start

      copy(data.bytes[l:], attributes[k].bytes[start:end])
      l += end - start
    }
  }

  assert(u32(l) == count)

  return data
}

get_mesh_attribute :: proc(mesh: ^Gltf_Mesh, kind: Gltf_Attribute_Kind) -> Gltf_Attribute {
  return mesh.primitives[0].attributes[kind].?
}

get_mesh_indices :: proc(mesh: ^Gltf_Mesh) -> Vertex_Data {
  data: Vertex_Data
  indices := mesh.primitives[0].indices.?

  data.size = indices.component_size * get_attribute_component_size(indices.component) 
  data.count = indices.count
  data.bytes = indices.bytes

  return data
}

get_attribute_component_size :: proc(kind: Gltf_Attribute_Component) -> u32 {
  switch kind {
    case .F32: return 4
    case .U16: return 2
  }

  panic("Invalid size")
}

get_animation_frame :: proc(animation: ^Gltf_Animation, time: f32, last: u32) -> (frame: Gltf_Animation_Frame, index: u32, repeat: bool, finished: bool) {
  length := u32(len(animation.frames))
  index = last

  for time > animation.frames[index].time {
    next_index := index + 1

    if next_index >= length {
      return animation.frames[index], index, false, true
    }

    index = next_index
  }

  return animation.frames[index], index, index == last, false
}

parse_asset :: proc(ctx: ^Gltf_Context) -> (asset: Gltf_Asset, err: Error) {
  raw := ctx.obj["asset"].(json.Object)

  asset.generator = raw["generator"].(string)
  asset.version = raw["version"].(string)

  return asset, nil
}

parse_node :: proc(ctx: ^Gltf_Context, raw: json.Object) -> (node: Gltf_Node, err: Error) {
  node.name = raw["name"].(string)

  index := u32(raw["mesh"].(f64))
  node.mesh = parse_mesh(ctx, ctx.raw_meshes[index].(json.Object)) or_return
  node.transform = matrix[4, 4]f32 {
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
  }

  if translation, ok := raw["translation"]; ok {
    t := translation.(json.Array)

    for i in 0..<len(t) {
      node.transform[i, 3] = cast(f32)t[i].(f64)
    }
  }

  if scale, ok := raw["scale"]; ok {
    s := scale.(json.Array)

    for i in 0..<len(s) {
      node.transform[i, i] = cast(f32)s[i].(f64)
    }
  }

  if rotation, ok := raw["rotation"]; ok {
    r := rotation.(json.Array)
    q: quaternion128 = quaternion(x = cast(f32)r[0].(f64), y = -cast(f32)r[1].(f64), z = -cast(f32)r[2].(f64), w = cast(f32)r[3].(f64))
    mat := linalg.matrix3_from_quaternion_f32(q)
    node.transform = linalg.matrix4_from_matrix3_f32(mat) * node.transform
  }

  return node, nil
}

parse_nodes :: proc(ctx: ^Gltf_Context) -> (nodes: []Gltf_Node, err: Error) {
  nodes = make([]Gltf_Node, len(ctx.raw_nodes), ctx.tmp_allocator)

  for i in 0..<len(ctx.raw_nodes) {
    nodes[i] = parse_node(ctx, ctx.raw_nodes[i].(json.Object)) or_return
  }

  return nodes, nil
}

parse_animation_sampler :: proc(ctx: ^Gltf_Context, raw: json.Object, path: Gltf_Animation_Path) -> (sampler: Gltf_Animation_Sampler, err: Error) {
  input := parse_attribute(ctx, ctx.raw_accessors[u32(raw["input"].(f64))].(json.Object)) or_return
  output := parse_attribute(ctx, ctx.raw_accessors[u32(raw["output"].(f64))].(json.Object)) or_return

  assert(input.component == .F32)
  assert(output.component == .F32)
  assert(input.component_size == 1)
  assert(input.count == output.count)

  sampler.objs = make([]Gltf_Animation_Sampler_Obj, input.count, ctx.tmp_allocator)
  output_vec := cast([^]f32)&output.bytes[0]
  input_vec := cast([^]f32)&input.bytes[0]//u32(i) * get_attribute_component_size(c.sampler.output.component) * c.sampler.output.component_size]

  identity := Matrix {
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
  }

  #partial switch path {
    case .Translation:
      assert(output.component_size == 3)
      for i in 0..<output.count {
        sampler.objs[i].transform = identity
        index := output.component_size * i
        sampler.objs[i].transform[0, 3] = output_vec[index + 0]
        sampler.objs[i].transform[1, 3] = output_vec[index + 1]
        sampler.objs[i].transform[2, 3] = output_vec[index + 2]
      }
    case .Scale:
      assert(output.component_size == 3)
      for i in 0..<output.count {
        sampler.objs[i].transform = identity
        index := output.component_size * i
        sampler.objs[i].transform[0, 0] = output_vec[index + 0]
        sampler.objs[i].transform[1, 1] = output_vec[index + 1]
        sampler.objs[i].transform[2, 2] = output_vec[index + 2]
      }
    case .Rotation:
      assert(output.component_size == 4)
      for i in 0..<output.count {
        sampler.objs[i].transform = identity
        index := output.component_size * i
        q: quaternion128 = quaternion(x = output_vec[index + 0], y = -output_vec[index + 1], z = -output_vec[index + 2], w = output_vec[index + 3])
        mat := linalg.matrix3_from_quaternion_f32(q)
        sampler.objs[i].transform = linalg.matrix4_from_matrix3_f32(mat)
      }
  }

  for i in 0..<input.count {
    sampler.objs[i].time = input_vec[i]
  }

  switch raw["interpolation"].(string) {
    case "LINEAR":
      sampler.interpolation = .Linear
    case "STEP":
      sampler.interpolation = .Step
    case "CUBICSPLINE":
      sampler.interpolation = .CubicSpline
    case:
      return sampler, .InvalidInterpolation
  }

  return sampler, err
}

parse_animation_target :: proc(ctx: ^Gltf_Context, raw: json.Object) -> (target: Gltf_Animation_Target, err: Error) {
  raw_node := u32(raw["node"].(f64))
  target.node = raw_node

  switch raw["path"].(string) {
    case "translation":
      target.path = .Translation
    case "rotation":
      target.path = .Rotation
    case "scale":
      target.path = .Scale
    case "weights":
      target.path = .Weights
    case:
      return target, .InvalidAnimationPath
  }

  return target, nil
}

parse_animation_channel :: proc(ctx: ^Gltf_Context, raw: json.Object, samplers: json.Array) -> (channel: Gltf_Animation_Channel, err: Error) {
  raw_sampler := samplers[u32(raw["sampler"].(f64))].(json.Object)

  channel.target = parse_animation_target(ctx, raw["target"].(json.Object)) or_return
  channel.sampler = parse_animation_sampler(ctx, raw_sampler, channel.target.path) or_return

  return channel, err
}

parse_frames :: proc(ctx: ^Gltf_Context, animation: ^Gltf_Animation, frame_count: u32, frame_time: f32) -> Error {
  NodeTransform :: [Gltf_Animation_Path]Maybe(Matrix)

  node_count := len(ctx.nodes)

  identity := Matrix { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, }
  frames := make([]Gltf_Animation_Frame, frame_count, ctx.allocator)

  for i in 0..<frame_count {
    frames[i].time = f32(i + 1) * frame_time
    frames[i].transforms = make([]Matrix, node_count, ctx.allocator)

    for &t in frames[i].transforms {
      t = identity
    }
  }

  for c in animation.channels {
    #partial switch c.sampler.interpolation {
      case .Step:
        i := 0

        transform := identity

        for k in 0..<len(c.sampler.objs) {
          for greater(c.sampler.objs[k].time, frames[i].time) {
            frames[i].transforms[c.target.node] = frames[i].transforms[c.target.node] * transform
            i += 1
          }

          transform = c.sampler.objs[k].transform
        }
      case .Linear:
        for i in 0..<len(c.sampler.objs) {
          frames[i].transforms[c.target.node] = frames[i].transforms[c.target.node] * c.sampler.objs[i].transform
        }
      case:
        panic("TODO")
    }
  }

  nodes := make([dynamic]u32, len(ctx.nodes), ctx.allocator)

  for c in animation.channels {
    append(&nodes, c.target.node)
  }

  animation.nodes = nodes[:]
  animation.frames = frames

  return nil
}

parse_animation :: proc(ctx: ^Gltf_Context, raw: json.Object) -> (name: string, animation: Gltf_Animation, err: Error) {
  name = strings.clone(raw["name"].(string), ctx.allocator)

  raw_channels := raw["channels"].(json.Array)
  raw_samplers := raw["samplers"].(json.Array)
  animation.channels = make([]Gltf_Animation_Channel, len(raw_channels), ctx.tmp_allocator)

  frame_count: u32 = 0
  frame_time: f32 = 0
  for i in 0..<len(raw_channels) {
    animation.channels[i] = parse_animation_channel(ctx, raw_channels[i].(json.Object), raw_samplers) or_return

    l := u32(len(animation.channels[i].sampler.objs))

    if frame_count < l {
      frame_count = l
      frame_time = animation.channels[i].sampler.objs[l - 1].time / f32(frame_count)
    }
  }

  parse_frames(ctx, &animation, frame_count, frame_time) or_return

  return name, animation, err
}

parse_animations :: proc(ctx: ^Gltf_Context) -> (animations: map[string]Gltf_Animation, err: Error) {
  raw := ctx.obj["animations"]

  if raw == nil {
    return animations, .NoAnimation
  }

  raw_array := raw.(json.Array)
  animations = make(map[string]Gltf_Animation, len(raw_array) * 2, ctx.allocator)

  for i in 0..<len(raw_array) {
    name, animation := parse_animation(ctx, raw_array[i].(json.Object)) or_return
    animations[name] = animation
  }

  return animations, nil
}

parse_attribute :: proc(ctx: ^Gltf_Context, raw: json.Object) -> (attribute: Gltf_Attribute, err: Error) {
  raw_view := ctx.raw_buffer_views[u32(raw["bufferView"].(f64))].(json.Object)
  buffer := ctx.buffers[u32(raw_view["buffer"].(f64))]

  length := u32(raw_view["byteLength"].(f64))
  offset := u32(raw_view["byteOffset"].(f64))
  // target := u32(raw_view["target"].(f64))

  attribute.bytes = read_from_buffer(ctx, buffer, length, offset) or_return
  attribute.count = u32(raw["count"].(f64))

  switch u32(raw["componentType"].(f64)) {
    case 5126:
      attribute.component = .F32
    case 5123:
      attribute.component = .U16
    case:
      return attribute, .InvalidAttributeKind
  }

  switch raw["type"].(string) {
    case "VEC4":
      attribute.component_size = 4
    case "VEC3":
      attribute.component_size = 3
    case "VEC2":
      attribute.component_size = 2
    case "SCALAR":
      attribute.component_size = 1
    case:
      return attribute, .InvalidAttributeKind
  }

  return attribute, nil
}

parse_material :: proc(ctx: ^Gltf_Context, raw: json.Object) -> (material: Gltf_Material, err: Error) {
  material.name = raw["name"].(string)
  material.double_sided = raw["doubleSided"].(bool)

  if attrib, ok := raw["pbrMetallicRoughness"]; ok {
    factor := attrib.(json.Object)["baseColorFactor"].(json.Array)
    material.metallic_roughness.base_color_factor = make([]f64, len(factor), ctx.tmp_allocator)

    for i in 0..<len(factor) {
      material.metallic_roughness.base_color_factor[i] = factor[i].(f64)
    }
  }

  if attrib, ok := raw["metallicFactor"]; ok {
    material.metallic_factor = attrib.(f64)
  }

  if attrib, ok := raw["roughnessFactor"]; ok {
    material.roughness_factor = attrib.(f64)
  }

  return material, nil
}

parse_mesh_primitive :: proc(ctx: ^Gltf_Context, raw: json.Object) -> (primitive: Gltf_Mesh_Primitive, err: Error) {
  raw_attributes := raw["attributes"].(json.Object)

  if attrib, ok := raw_attributes["POSITION"]; ok {
    index := u32(attrib.(f64))
    primitive.attributes[.Position] = parse_attribute(ctx, ctx.raw_accessors[index].(json.Object)) or_return
  }

  if attrib, ok := raw_attributes["NORMAL"]; ok {
    index := u32(attrib.(f64))
    primitive.attributes[.Normal] = parse_attribute(ctx, ctx.raw_accessors[index].(json.Object)) or_return
  }

  if attrib, ok := raw_attributes["COLOR_0"]; ok {
    index := u32(attrib.(f64))
    primitive.attributes[.Color0] = parse_attribute(ctx, ctx.raw_accessors[index].(json.Object)) or_return
  }

  if attrib, ok := raw_attributes["JOINTS_0"]; ok {
    index := u32(attrib.(f64))
    primitive.attributes[.Joint0] = parse_attribute(ctx, ctx.raw_accessors[index].(json.Object)) or_return
  }

  if attrib, ok := raw_attributes["WEIGHTS_0"]; ok {
    index := u32(attrib.(f64))
    primitive.attributes[.Weight0] = parse_attribute(ctx, ctx.raw_accessors[index].(json.Object)) or_return
  }

  if attrib, ok := raw_attributes["TEXCOORD_0"]; ok {
    index := u32(attrib.(f64))
    primitive.attributes[.Texture0] = parse_attribute(ctx, ctx.raw_accessors[index].(json.Object)) or_return
  }

  if attrib, ok := raw_attributes["TEXCOORD_1"]; ok {
    index := u32(attrib.(f64))
    primitive.attributes[.Texture1] = parse_attribute(ctx, ctx.raw_accessors[index].(json.Object)) or_return
  }

  if indices, ok := raw["indices"]; ok {
    index := u32(indices.(f64))
    primitive.indices = parse_attribute(ctx, ctx.raw_accessors[index].(json.Object)) or_return
  }

  {
    count: Maybe(u32)

    for attrib in primitive.attributes {
      if attrib == nil {
        continue
      }

      if count != nil && count.? != attrib.?.count {
        return primitive, .InvalidAttributeCount
      }

      count = attrib.?.count
    }
  }

  if material, ok := raw["material"]; ok {
    index := u32(material.(f64))
    primitive.material = parse_material(ctx, ctx.raw_materials[index].(json.Object)) or_return
  }

  return primitive, nil
}

parse_mesh :: proc(ctx: ^Gltf_Context, raw: json.Object) -> (mesh: Gltf_Mesh, err: Error) {
  mesh.name = raw["name"].(string)

  raw_primitives := raw["primitives"].(json.Array)
  mesh.primitives = make([]Gltf_Mesh_Primitive, len(raw_primitives), ctx.tmp_allocator)

  for i in 0..<len(raw_primitives) {
    mesh.primitives[i] = parse_mesh_primitive(ctx, raw_primitives[i].(json.Object)) or_return
  }

  return mesh, nil
}

parse_scene :: proc(ctx: ^Gltf_Context, raw: json.Object) -> (name: string, scene: Gltf_Scene, err: Error) {
  name = raw["name"].(string)

  raw_nodes := raw["nodes"].(json.Array)
  scene.nodes = make([]Gltf_Node, len(raw_nodes), ctx.tmp_allocator)

  for i in 0..<len(raw_nodes) {
    index := u32(raw_nodes[i].(f64))
    scene.nodes[i] = ctx.nodes[index]
  }
  return name, scene, nil
}

parse_scenes :: proc(ctx: ^Gltf_Context) -> (scenes: map[string]Gltf_Scene, err: Error) {
  raw := ctx.obj["scenes"].(json.Array)
  scenes = make(map[string]Gltf_Scene, len(raw) * 2, ctx.allocator)

  for i in 0..<len(raw) {
    name, scene := parse_scene(ctx, raw[i].(json.Object)) or_return
    scenes[name] = scene
  }

  return scenes, nil
}

read_from_buffer :: proc(ctx: ^Gltf_Context, buffer: Gltf_Buffer, length: u32, offset: u32) -> (bytes: []u8, err: Error) {
  i: i64
  e: os.Error
  bytes = make([]u8, length, ctx.tmp_allocator)

  if i, e = os.seek(buffer.fd, i64(offset), os.SEEK_SET); e != nil do return bytes, .FileNotFound

  read: int
  if read, e = os.read(buffer.fd, bytes); e != nil do return bytes, .ReadFileFailed
  if read != int(length) do return bytes, .ReadFileFailed

  return bytes, nil
}

greater :: proc(first, second: f32) -> bool {
  return first > second + 0.001
}
