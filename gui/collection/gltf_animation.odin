package collection

import "core:encoding/json"
import "core:math/linalg"
import "core:strings"

import "./../error"

Gltf_Animation_Interpolation :: enum {
  Linear,
  Step,
  CubicSpline,
}

Gltf_Animation_Sampler_Obj :: struct {
  time: f32,
  transform: Matrix,
}

Gltf_Animation_Path :: enum {
  Translation,
  Rotation,
  Scale,
  Weights,
}

Gltf_Animation_Channel :: struct {
  interpolation: Gltf_Animation_Interpolation,
  objs: []Gltf_Animation_Sampler_Obj,
  node: u32,
}

Gltf_Animation_Frame :: struct {
  time: f32,
  transforms: []Matrix,
}

Gltf_Animation :: struct {
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

parse_animation_channel :: proc(ctx: ^Gltf_Context, raw: json.Object, samplers: json.Array) -> (channel: Gltf_Animation_Channel, err: error.Error) {
  raw_sampler := samplers[u32(raw["sampler"].(f64))].(json.Object)
  raw_target := raw["target"].(json.Object)

  raw_node := u32(raw_target["node"].(f64))
  channel.node = raw_node
  path: Gltf_Animation_Path

  switch raw_target["path"].(string) {
    case "translation":
      path = .Translation
    case "rotation":
      path = .Rotation
    case "scale":
      path = .Scale
    case "weights":
      path = .Weights
    case:
      return channel, .InvalidAnimationPath
  }

  input := &ctx.accessors[u32(raw_sampler["input"].(f64))]
  output := &ctx.accessors[u32(raw_sampler["output"].(f64))]

  assert(input.component == .F32)
  assert(output.component == .F32)
  assert(input.component_size == 1)
  assert(input.count == output.count)

  channel.objs = make([]Gltf_Animation_Sampler_Obj, input.count, ctx.tmp_allocator)
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
        channel.objs[i].transform = identity
        index := output.component_size * i
        channel.objs[i].transform[0, 3] = output_vec[index + 0]
        channel.objs[i].transform[1, 3] = output_vec[index + 1]
        channel.objs[i].transform[2, 3] = output_vec[index + 2]
      }
    case .Scale:
      assert(output.component_size == 3)
      for i in 0..<output.count {
        channel.objs[i].transform = identity
        index := output.component_size * i
        channel.objs[i].transform[0, 0] = output_vec[index + 0]
        channel.objs[i].transform[1, 1] = output_vec[index + 1]
        channel.objs[i].transform[2, 2] = output_vec[index + 2]
      }
    case .Rotation:
      assert(output.component_size == 4)
      for i in 0..<output.count {
        channel.objs[i].transform = identity
        index := output.component_size * i
        q: quaternion128 = quaternion(x = output_vec[index + 0], y = -output_vec[index + 1], z = -output_vec[index + 2], w = output_vec[index + 3])
        mat := linalg.matrix3_from_quaternion_f32(q)
        channel.objs[i].transform = linalg.matrix4_from_matrix3_f32(mat)
      }
  }

  for i in 0..<input.count {
    channel.objs[i].time = input_vec[i]
  }

  switch raw_sampler["interpolation"].(string) {
    case "LINEAR":
      channel.interpolation = .Linear
    case "STEP":
      channel.interpolation = .Step
    case "CUBICSPLINE":
      channel.interpolation = .CubicSpline
    case:
      return channel, .InvalidInterpolation
  }

  return channel, err
}

parse_frames :: proc(ctx: ^Gltf_Context, animation: ^Gltf_Animation, channels: []Gltf_Animation_Channel, frame_count: u32, frame_time: f32) -> error.Error {
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

  for c in channels {
    #partial switch c.interpolation {
      case .Step:
        i := 0

        transform := identity

        for k in 0..<len(c.objs) {
          for greater(c.objs[k].time, frames[i].time) {
            frames[i].transforms[c.node] = frames[i].transforms[c.node] * transform
            i += 1
          }

          transform = c.objs[k].transform
        }
      case .Linear:
        for i in 0..<len(c.objs) {
          frames[i].transforms[c.node] = frames[i].transforms[c.node] * c.objs[i].transform
        }
      case:
        panic("TODO")
    }
  }

  nodes := make([dynamic]u32, len(ctx.nodes), ctx.allocator)

  for c in channels {
    append(&nodes, c.node)
  }

  animation.nodes = nodes[:]
  animation.frames = frames

  return nil
}

parse_animation :: proc(ctx: ^Gltf_Context, raw: json.Object) -> (name: string, animation: Gltf_Animation, err: error.Error) {
  name = strings.clone(raw["name"].(string), ctx.allocator)

  raw_channels := raw["channels"].(json.Array)
  raw_samplers := raw["samplers"].(json.Array)
  channels := make([]Gltf_Animation_Channel, len(raw_channels), ctx.tmp_allocator)

  frame_count: u32 = 0
  frame_time: f32 = 0
  for i in 0..<len(raw_channels) {
    channels[i] = parse_animation_channel(ctx, raw_channels[i].(json.Object), raw_samplers) or_return

    l := u32(len(channels[i].objs))

    if frame_count < l {
      frame_count = l
      frame_time = channels[i].objs[l - 1].time / f32(frame_count)
    }
  }

  parse_frames(ctx, &animation, channels, frame_count, frame_time) or_return

  return name, animation, err
}

parse_animations :: proc(ctx: ^Gltf_Context) -> (animations: map[string]Gltf_Animation, err: error.Error) {
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
