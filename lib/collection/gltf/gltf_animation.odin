package gltf

import "core:encoding/json"
import "core:log"
import "core:math/linalg"
import "core:mem"
import "core:slice"
import "core:strings"

import "lib:collection/vector"
import "lib:error"

FRAME_TIME :: 1.0 / 24.0

@(private)
Animation_Interpolation :: enum {
  Linear,
  Step,
}

@(private)
Animation_Path :: enum {
  Translation,
  Rotation,
  Scale,
}

@(private)
Animation_Sampler :: struct {
  input:         ^Accessor,
  output:        ^Accessor,
  interpolation: Animation_Interpolation,
}

@(private)
Animation_Target :: struct {
  node: u32,
  path: Animation_Path,
}

@(private)
Animation_Channel :: struct {
  sampler: ^Animation_Sampler,
  target:  Animation_Target,
}

Animation_Frame :: struct {
  time:       f32,
  transforms: vector.Vector(Transform),
}

Animation :: struct {
  name:   string,
  frames: vector.Vector(Animation_Frame),
}

@(private)
parse_translation :: proc(transform: ^Transform, output: [3]f32) {
  transform.translate = output
}

@(private)
parse_rotation :: proc(transform: ^Transform, output: [4]f32) {
  transform.rotate = output
}

@(private)
parse_scale :: proc(transform: ^Transform, output: [3]f32) {
  transform.scale = output
}

@(private)
parse_step :: proc(
  $T: typeid,
  channel: ^Animation_Channel,
  frames: vector.Vector(Animation_Frame),
  input: []f32,
  output: []T,
  function: proc(tranform: ^Transform, output: T),
) {
  k := 0

  for i in 0 ..< frames.len {
    frame := &frames.data[i]
    transform := &frame.transforms.data[channel.target.node]

    if frame.time >= input[k] {
      k += 1
    }

    function(transform, output[k - 1])
  }
}

@(private)
parse_linear :: proc(
  $T: typeid,
  channel: ^Animation_Channel,
  frames: vector.Vector(Animation_Frame),
  input: []f32,
  output: []T,
  parse: proc(transform: ^Transform, output: T),
) {
  k := 0

  for i in 0 ..< frames.len {
    frame := &frames.data[i]
    transform := &frame.transforms.data[channel.target.node]

    if frames.data[i].time >= input[k] {
      k += 1
      parse(transform, output[k - 1])
    } else {
      delta := (input[k] - frame.time) / (input[k] - input[k - 1])
      parse(transform, output[k - 1] * delta + output[k] * (1.0 - delta))
    }
  }
}

@(private)
parse_animation_target :: proc(
  ctx: ^Context,
  raw: json.Object,
) -> (
  target: Animation_Target,
  err: error.Error,
) {
  target.node = u32(raw["node"].(f64))

  switch raw["path"].(string) {
  case "translation":
    target.path = .Translation
  case "rotation":
    target.path = .Rotation
  case "scale":
    target.path = .Scale
  case:
    return target, .InvalidAnimationPath
  }

  return target, nil
}

@(private)
parse_animation_channel :: proc(
  ctx: ^Context,
  raw: json.Object,
  samplers: vector.Vector(Animation_Sampler),
) -> (
  channel: Animation_Channel,
  err: error.Error,
) {
  channel.sampler = &samplers.data[u32(raw["sampler"].(f64))]
  channel.target = parse_animation_target(
    ctx,
    raw["target"].(json.Object),
  ) or_return

  return channel, nil
}

@(private)
parse_animation_channels :: proc(
  ctx: ^Context,
  raw: json.Array,
  samplers: vector.Vector(Animation_Sampler),
) -> (
  channels: []Animation_Channel,
  err: error.Error,
) {
  channels = make([]Animation_Channel, len(raw), ctx.allocator)

  for i in 0 ..< len(raw) {
    channels[i] = parse_animation_channel(
      ctx,
      raw[i].(json.Object),
      samplers,
    ) or_return
  }

  return channels, nil
}

@(private)
parse_animation_sampler :: proc(
  ctx: ^Context,
  raw: json.Object,
) -> (
  sampler: Animation_Sampler,
  err: error.Error,
) {
  sampler.input = &ctx.accessors.data[u32(raw["input"].(f64))]
  sampler.output = &ctx.accessors.data[u32(raw["output"].(f64))]

  switch raw["interpolation"].(string) {
  case "STEP":
    sampler.interpolation = .Step
  case "LINEAR":
    sampler.interpolation = .Linear
  case:
    return sampler, .InvalidAnimationInterpolation
  }

  return sampler, nil
}

@(private)
parse_animation_samplers :: proc(
  ctx: ^Context,
  raw: json.Array,
) -> (
  samplers: vector.Vector(Animation_Sampler),
  err: error.Error,
) {
  samplers = vector.new(
    Animation_Sampler,
    u32(len(raw)),
    ctx.allocator,
  ) or_return

  for i in 0 ..< len(raw) {
    vector.append(
      &samplers,
      parse_animation_sampler(ctx, raw[i].(json.Object)) or_return,
    ) or_return
  }

  return samplers, nil
}

@(private)
parse_channel_transforms :: proc(
  ctx: ^Context,
  channel: ^Animation_Channel,
  frames: vector.Vector(Animation_Frame),
) -> error.Error {
  assert(channel.sampler.input.component_kind == .F32)
  assert(channel.sampler.output.component_kind == .F32)
  assert(channel.sampler.input.component_count == 1)
  assert(channel.sampler.input.count == channel.sampler.output.count)

  input := mem.slice_data_cast([]f32, channel.sampler.input.bytes)

  switch channel.target.path {
  case .Translation:
    assert(channel.sampler.output.component_count == 3)
    output := mem.slice_data_cast([][3]f32, channel.sampler.output.bytes)

    switch channel.sampler.interpolation {
    case .Step:
      parse_step([3]f32, channel, frames, input, output, parse_translation)
    case .Linear:
      parse_linear([3]f32, channel, frames, input, output, parse_translation)
    }
  case .Scale:
    assert(channel.sampler.output.component_count == 3)
    output := mem.slice_data_cast([][3]f32, channel.sampler.output.bytes)

    switch channel.sampler.interpolation {
    case .Step:
      parse_step([3]f32, channel, frames, input, output, parse_scale)
    case .Linear:
      parse_linear([3]f32, channel, frames, input, output, parse_scale)
    }
  case .Rotation:
    assert(channel.sampler.output.component_count == 4)
    output := mem.slice_data_cast([][4]f32, channel.sampler.output.bytes)

    switch channel.sampler.interpolation {
    case .Step:
      parse_step([4]f32, channel, frames, input, output, parse_rotation)
    case .Linear:
      parse_linear([4]f32, channel, frames, input, output, parse_rotation)
    }
  }

  return nil
}

@(private)
parse_frames :: proc(
  ctx: ^Context,
  channels: []Animation_Channel,
  input: []f32,
) -> (
  frames: vector.Vector(Animation_Frame),
  err: error.Error,
) {
  frames = vector.new(
    Animation_Frame,
    u32(len(input)),
    ctx.allocator,
  ) or_return

  for i in 0 ..< len(input) {
    frame := vector.one(&frames) or_return

    frame.time = input[i]
    frame.transforms = vector.new(
      Transform,
      ctx.nodes.len,
      ctx.allocator,
    ) or_return

    for i in 0 ..< ctx.nodes.len {
      transform := vector.one(&frame.transforms) or_return

      transform.rotate = {0, 0, 0, 0}
      transform.translate = {0, 0, 0}
      transform.scale = {1, 1, 1}
      transform.compose = linalg.MATRIX4F32_IDENTITY
    }
  }

  for &channel in channels {
    parse_channel_transforms(ctx, &channel, frames) or_return
  }

  return frames, nil
}

@(private)
parse_animation :: proc(
  ctx: ^Context,
  raw: json.Object,
) -> (
  animation: Animation,
  err: error.Error,
) {
  animation.name = strings.clone(raw["name"].(string), ctx.allocator)

  samplers := parse_animation_samplers(
    ctx,
    raw["samplers"].(json.Array),
  ) or_return

  channels := parse_animation_channels(
    ctx,
    raw["channels"].(json.Array),
    samplers,
  ) or_return

  frame_count: u32 = 0
  input: []f32

  for i in 0 ..< samplers.len {
    if samplers.data[i].input.count > frame_count {
      frame_count = samplers.data[i].input.count
      input := mem.slice_data_cast([]f32, samplers.data[i].input.bytes)
    }
  }

  assert(frame_count > 0)

  animation.frames = parse_frames(ctx, channels, input) or_return

  return animation, nil
}

@(private)
parse_animations :: proc(ctx: ^Context) -> error.Error {
  for i in 0 ..< len(ctx.raw_animations) {
    vector.append(
      &ctx.animations,
      parse_animation(ctx, ctx.raw_animations[i].(json.Object)) or_return,
    ) or_return
  }

  return nil
}
