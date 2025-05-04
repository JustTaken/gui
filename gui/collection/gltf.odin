package collection

import "base:runtime"
import "core:os"
import "core:log"
import "core:encoding/json"
import "core:path/filepath"
import "core:math/linalg"

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

Gltf_Animation_Sampler :: struct {
  interpolation: Gltf_Animation_Interpolation,
  input: Gltf_Attribute,
  output: Gltf_Attribute,
}

Gltf_Animation_Path :: enum {
  Translation,
  Rotation,
  Scale,
  Weights,
}

Gltf_Animation_Target :: struct {
  node: Gltf_Node,
  path: Gltf_Animation_Path,
}

Gltf_Animation_Channel :: struct {
  sampler: Gltf_Animation_Sampler,
  target: Gltf_Animation_Target,
}

Gltf_Animation :: struct {
  channels: []Gltf_Animation_Channel,
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
}

Gltf :: struct {
  asset: Gltf_Asset,
  scenes: map[string]Gltf_Scene,
  animations: map[string]Gltf_Animation,
}

gltf_from_file :: proc(path: string, allocator: runtime.Allocator) -> (gltf: Gltf, err: Error) {
  value: json.Value
  j_err: json.Error
  bytes: []u8
  ok: bool
  os_err: os.Error

  log.info("Parsing", path)

  ctx: Gltf_Context
  ctx.allocator = allocator

  if bytes, ok = os.read_entire_file(path); !ok do return gltf, .FileNotFound
  if value, j_err = json.parse(bytes, allocator = ctx.allocator); j_err != nil do return gltf, .GltfLoadFailed
  dir := filepath.dir(path, ctx.allocator)

  ctx.obj = value.(json.Object)

  ctx.raw_accessors = ctx.obj["accessors"].(json.Array)
  ctx.raw_buffer_views = ctx.obj["bufferViews"].(json.Array)
  ctx.raw_meshes = ctx.obj["meshes"].(json.Array)
  ctx.raw_nodes = ctx.obj["nodes"].(json.Array)

  if materials, ok := ctx.obj["materials"]; ok {
    ctx.raw_materials = materials.(json.Array)
  }

  raw_buffers := ctx.obj["buffers"].(json.Array)
  ctx.buffers = make([]Gltf_Buffer, len(raw_buffers), ctx.allocator)

  for i in 0 ..< len(raw_buffers) {
    buffer := &ctx.buffers[i]
    raw := &raw_buffers[i].(json.Object)

    uri_array := [?]string{dir, raw["uri"].(string)}
    uri := filepath.join(uri_array[:], ctx.allocator)

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

get_animation_frame :: proc(animation: ^Gltf_Animation, frame: u32) -> matrix[4, 4]f32 {
  m := matrix[4, 4]f32 {
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
  }

  for c in animation.channels {
    #partial switch c.target.path {
      case .Translation:
        vec := cast([^]f32)&c.sampler.output.bytes[frame * get_attribute_component_size(c.sampler.output.component) * c.sampler.output.component_size]
        m[0, 3] += vec[0]
        m[1, 3] += vec[1]
        m[2, 3] += vec[2]
      case .Scale:
        vec := cast([^]f32)&c.sampler.output.bytes[frame * get_attribute_component_size(c.sampler.output.component) * c.sampler.output.component_size]
        m[0, 0] *= vec[0]
        m[1, 1] *= vec[1]
        m[2, 2] *= vec[2]
      case .Rotation:
        vec := cast([^]f32)&c.sampler.output.bytes[frame * get_attribute_component_size(c.sampler.output.component) * c.sampler.output.component_size]
        q: quaternion128 = quaternion(x = vec[0], y = -vec[1], z = -vec[2], w = vec[3])
        mat := linalg.matrix3_from_quaternion_f32(q)
        m = linalg.matrix4_from_matrix3_f32(mat) * m
    }
  }

  return m
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
  nodes = make([]Gltf_Node, len(ctx.raw_nodes), ctx.allocator)

  for i in 0..<len(ctx.raw_nodes) {
    nodes[i] = parse_node(ctx, ctx.raw_nodes[i].(json.Object)) or_return
  }

  return nodes, nil
}

parse_animation_sampler :: proc(ctx: ^Gltf_Context, raw: json.Object) -> (sampler: Gltf_Animation_Sampler, err: Error) {
  sampler.input = parse_attribute(ctx, ctx.raw_accessors[u32(raw["input"].(f64))].(json.Object)) or_return
  sampler.output = parse_attribute(ctx, ctx.raw_accessors[u32(raw["output"].(f64))].(json.Object)) or_return

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
  target.node = ctx.nodes[raw_node]

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

  channel.sampler = parse_animation_sampler(ctx, raw_sampler) or_return
  channel.target = parse_animation_target(ctx, raw["target"].(json.Object)) or_return

  return channel, err
}

parse_animation :: proc(ctx: ^Gltf_Context, raw: json.Object) -> (name: string, animation: Gltf_Animation, err: Error) {
  name = raw["name"].(string)

  raw_channels := raw["channels"].(json.Array)
  raw_samplers := raw["samplers"].(json.Array)
  animation.channels = make([]Gltf_Animation_Channel, len(raw_channels), ctx.allocator)

  for i in 0..<len(raw_channels) {
    animation.channels[i] = parse_animation_channel(ctx, raw_channels[i].(json.Object), raw_samplers) or_return
  }

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
    material.metallic_roughness.base_color_factor = make([]f64, len(factor), ctx.allocator)

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
  mesh.primitives = make([]Gltf_Mesh_Primitive, len(raw_primitives), ctx.allocator)

  for i in 0..<len(raw_primitives) {
    mesh.primitives[i] = parse_mesh_primitive(ctx, raw_primitives[i].(json.Object)) or_return
  }

  return mesh, nil
}

parse_scene :: proc(ctx: ^Gltf_Context, raw: json.Object) -> (name: string, scene: Gltf_Scene, err: Error) {
  name = raw["name"].(string)

  raw_nodes := raw["nodes"].(json.Array)
  scene.nodes = make([]Gltf_Node, len(raw_nodes), ctx.allocator)

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
  bytes = make([]u8, length, ctx.allocator)

  if i, e = os.seek(buffer.fd, i64(offset), os.SEEK_SET); e != nil do return bytes, .FileNotFound

  read: int
  if read, e = os.read(buffer.fd, bytes); e != nil do return bytes, .ReadFileFailed
  if read != int(length) do return bytes, .ReadFileFailed

  return bytes, nil
}
