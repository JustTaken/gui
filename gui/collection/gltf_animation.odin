package collection

import "core:encoding/json"
import "core:math/linalg"
import "core:strings"

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

parse_animation_sampler :: proc(ctx: ^Gltf_Context, raw: json.Object, path: Gltf_Animation_Path) -> (sampler: Gltf_Animation_Sampler, err: Error) {
  input := parse_attribute(ctx, ctx.raw_accessors[u32(raw["input"].(f64))].(json.Object)) or_return
  output := parse_attribute(ctx, ctx.raw_accessors[u32(raw["output"].(f64))].(json.Object)) or_return

  assert(input.component == .F32)
  assert(output.component == .F32)
  assert(input.component_size == 1)
  assert(input.count == output.count)

  sampler.objs = make([]Gltf_Animation_Sampler_Obj, input.count, ctx.tmp_allocator)
  output_vec := cast([^]f32)&output.bytes[0]
  input_vec := cast([^]f32)&input.bytes[0]

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
