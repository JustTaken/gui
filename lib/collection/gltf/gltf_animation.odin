package gltf

import "core:encoding/json"
import "core:log"
import "core:math/linalg"
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
parse_rotation :: proc(
  channel: ^Animation_Channel,
  frames: vector.Vector(Animation_Frame),
) -> error.Error {
  assert(channel.sampler.input.component_kind == .F32)
  assert(channel.sampler.output.component_kind == .F32)
  assert(channel.sampler.input.component_count == 1)
  assert(channel.sampler.output.component_count == 4)
  assert(channel.sampler.input.count == channel.sampler.output.count)

  input := (cast([^]f32)raw_data(
      channel.sampler.input.bytes,
    ))[0:channel.sampler.input.count]

  output := (cast([^][4]f32)raw_data(
      channel.sampler.output.bytes,
    ))[0:channel.sampler.output.count]

  #partial switch channel.sampler.interpolation {
  case .Linear:
    k := 0

    for i in 0 ..< frames.len {
      if frames.data[i].time >= input[k] {
        k += 1
        frames.data[i].transforms.data[channel.target.node].rotate =
          output[k - 1]
      } else {
        delta := (input[k] - frames.data[i].time) / (input[k] - input[k - 1])
        frames.data[i].transforms.data[channel.target.node].rotate =
          output[k - 1] * delta + output[k] * (1.0 - delta)
      }
    }
  case .Step:
    k := 0

    for i in 0 ..< frames.len {
      if frames.data[i].time >= input[k] {
        k += 1
      }

      frames.data[i].transforms.data[channel.target.node].rotate =
        output[k - 1]
    }
  case:
    return .InvalidAnimationInterpolation
  }

  return nil
}

@(private)
parse_translation :: proc(
  channel: ^Animation_Channel,
  frames: vector.Vector(Animation_Frame),
) -> error.Error {
  assert(channel.sampler.input.component_kind == .F32)
  assert(channel.sampler.output.component_kind == .F32)
  assert(channel.sampler.input.component_count == 1)
  assert(channel.sampler.output.component_count == 3)
  assert(channel.sampler.input.count == channel.sampler.output.count)

  input := (cast([^]f32)raw_data(
      channel.sampler.input.bytes,
    ))[0:channel.sampler.input.count]

  output := (cast([^][3]f32)raw_data(
      channel.sampler.output.bytes,
    ))[0:channel.sampler.output.count]

  #partial switch channel.sampler.interpolation {
  case .Linear:
    k := 0

    for i in 0 ..< frames.len {
      if frames.data[i].time >= input[k] {
        k += 1
        frames.data[i].transforms.data[channel.target.node].translate =
          output[k - 1]
      } else {
        delta := (input[k] - frames.data[i].time) / (input[k] - input[k - 1])
        frames.data[i].transforms.data[channel.target.node].translate =
          output[k - 1] * delta + output[k] * (1.0 - delta)
      }
    }
  case .Step:
    k := 0

    for i in 0 ..< frames.len {
      if frames.data[i].time >= input[k] {
        k += 1
      }

      frames.data[i].transforms.data[channel.target.node].translate =
        output[k - 1]
    }
  case:
    return .InvalidAnimationInterpolation
  }

  return nil
}

@(private)
parse_scale :: proc(
  channel: ^Animation_Channel,
  frames: vector.Vector(Animation_Frame),
) -> error.Error {
  assert(channel.sampler.input.component_kind == .F32)
  assert(channel.sampler.output.component_kind == .F32)
  assert(channel.sampler.input.component_count == 1)
  assert(channel.sampler.output.component_count == 3)
  assert(channel.sampler.input.count == channel.sampler.output.count)

  input := (cast([^]f32)raw_data(
      channel.sampler.input.bytes,
    ))[0:channel.sampler.input.count]

  output := (cast([^][3]f32)raw_data(
      channel.sampler.output.bytes,
    ))[0:channel.sampler.output.count]

  #partial switch channel.sampler.interpolation {
  case .Linear:
    k := 0

    for i in 0 ..< frames.len {
      if frames.data[i].time >= input[k] {
        k += 1
        frames.data[i].transforms.data[channel.target.node].scale =
          output[k - 1]
      } else {
        delta := (input[k] - frames.data[i].time) / (input[k] - input[k - 1])
        frames.data[i].transforms.data[channel.target.node].scale =
          output[k - 1] * delta + output[k] * (1.0 - delta)
      }
    }
  case .Step:
    k := 0

    for i in 0 ..< frames.len {
      if frames.data[i].time >= input[k] {
        k += 1
      }

      frames.data[i].transforms.data[channel.target.node].scale = output[k - 1]
    }
  case:
    return .InvalidAnimationInterpolation
  }

  return nil
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

  interpolation := raw["interpolation"].(string)
  switch interpolation {
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
  switch channel.target.path {
  case .Translation:
    parse_translation(channel, frames) or_return
  case .Scale:
    parse_scale(channel, frames) or_return
  case .Rotation:
    parse_rotation(channel, frames) or_return
  }

  return nil
}

@(private)
parse_frames :: proc(
  ctx: ^Context,
  channels: []Animation_Channel,
  sampler: ^Animation_Sampler,
) -> (
  frames: vector.Vector(Animation_Frame),
  err: error.Error,
) {
  frames = vector.new(
    Animation_Frame,
    sampler.input.count,
    ctx.allocator,
  ) or_return

  input := (cast([^]f32)raw_data(sampler.input.bytes))[0:sampler.input.count]

  for i in 0 ..< sampler.input.count {
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
  greater_sampler: ^Animation_Sampler = nil

  for i in 0 ..< samplers.len {
    if samplers.data[i].input.count > frame_count {
      frame_count = samplers.data[i].input.count
      greater_sampler = &samplers.data[i]
    }
  }

  assert(greater_sampler != nil)

  animation.frames = parse_frames(ctx, channels, greater_sampler) or_return

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
