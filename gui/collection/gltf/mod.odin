package gltf

import "base:runtime"
import "core:os"
import "core:log"
import "core:encoding/json"
import "core:fmt"
import "core:path/filepath"
import "core:math/linalg"

import "core:testing"
import "./../../error"

@private
Matrix :: matrix[4, 4]f32

Transform :: struct {
  translate: [3]f32,
  scale: [3]f32,
  rotate: [4]f32,
  compose: Matrix,
}

@private
Context :: struct {
  bytes: []u8,
  dir: string,

  obj: json.Object,

  raw_scenes: json.Array,
  raw_animations: json.Array,
  raw_buffers: json.Array,
  raw_buffer_views: json.Array,
  raw_materials: json.Array,
  raw_meshes: json.Array,
  raw_skins: json.Array,
  raw_accessors: json.Array,
  raw_nodes: json.Array,

  asset: Asset,
  accessors: []Accessor,
  materials: []Material,
  meshes: []Mesh,
  nodes: []Node,
  skins: []Skin,
  buffers: []Buffer,
  buffer_views: []Buffer_View,
  inverse_binding: []Matrix,
  animations: []Animation,
  scenes: map[string]Scene,
  allocator: runtime.Allocator,
}

Gltf :: struct {
  scenes: map[string]Scene,
  animations: []Animation,
  nodes: []Node,
  skins: []Skin,
  meshes: []Mesh,
}

from_file :: proc(path: string, allocator: runtime.Allocator) -> (gltf: Gltf, err: error.Error) {
  log.info("Loading Gltf from file path:", path)

  ctx: Context
  ctx.allocator = allocator

  if bytes, ok := os.read_entire_file(path, allocator = ctx.allocator); ok {
    if value, j_err := json.parse(bytes, allocator = ctx.allocator); j_err == nil {
        ctx.obj = value.(json.Object)
    } else do return gltf, .GltfLoadFailed
  } else do return gltf, .FileNotFound

  ctx.dir = filepath.dir(path, ctx.allocator)

  parse_asset(&ctx) or_return
  parse_buffers(&ctx) or_return
  parse_buffer_views(&ctx) or_return
  parse_accessors(&ctx) or_return
  parse_meshes(&ctx) or_return
  parse_skins(&ctx) or_return
  parse_animations(&ctx) or_return
  parse_nodes(&ctx) or_return
  parse_scenes(&ctx) or_return

  gltf.scenes = ctx.scenes
  gltf.nodes = ctx.nodes
  gltf.meshes = ctx.meshes
  gltf.skins = ctx.skins
  gltf.animations = ctx.animations

  return gltf, nil
}

@private
transform_apply :: proc(transform: ^Transform) {
  translate := linalg.matrix4_translate_f32(transform.translate)
  rotate := linalg.matrix4_from_quaternion_f32(quaternion(x = transform.rotate[0], y = transform.rotate[1], z = transform.rotate[2], w = transform.rotate[3]))
  scale := linalg.matrix4_scale_f32(transform.scale)

  transform.compose = translate * rotate * scale
}

// @private
// transform_inverse :: proc(transform: Transform) -> Matrix {
//   norm := transform.rotate[0] * transform.rotate[0] + transform.rotate[1] * transform.rotate[1] + transform.rotate[2] * transform.rotate[2] + transform.rotate[3] * transform.rotate[3]
//   if norm == 0 {
//     norm = 1
//   }

//   translate := linalg.matrix4_translate_f32({-transform.translate[0], -transform.translate[1], -transform.translate[2]})
//   rotate := linalg.matrix4_from_quaternion_f32(quaternion(x = -transform.rotate[0], y = -transform.rotate[1], z = -transform.rotate[2], w = transform.rotate[3]))
//   // rotate := linalg.matrix4_from_quaternion_f32(quaternion(x = -transform.rotate[0] / norm, y = -transform.rotate[1] / norm, z = -transform.rotate[2] / norm, w = transform.rotate[3] / norm))
//   scale := linalg.matrix4_scale_f32({1.0 / transform.scale[0], 1.0 / transform.scale[1], 1.0 / transform.scale[2]})

//   log.info("INVERSE:", [3]f32{-transform.translate[0], -transform.translate[1], -transform.translate[2]}, [4]f32{-transform.rotate[0] / norm, -transform.rotate[1] / norm, -transform.rotate[2] / norm, transform.rotate[3] / norm}, [3]f32{1.0 / transform.scale[0], 1.0 / transform.scale[1], 1.0 / transform.scale[2]})
//   log.info("INVERSE:", quaternion(x = -transform.rotate[0] / norm, y = -transform.rotate[1] / norm, z = -transform.rotate[2] / norm, w = transform.rotate[3] / norm) * quaternion(x = transform.rotate[0], y = transform.rotate[1], z = transform.rotate[2], w = transform.rotate[3]), [3]f32{1.0 / transform.scale[0], 1.0 / transform.scale[1], 1.0 / transform.scale[2]})
//   log.info("INVERSE:", translate * rotate * scale)
//   log.info("LINALG INVERSE:", linalg.inverse(transform.compose))

//   return linalg.inverse(transform.compose)
// }

@test
first_test :: proc(t: ^testing.T) {
  glt: Gltf
  err: error.Error
  glt, err = from_file("assets/cube_animation.gltf", context.allocator)

  testing.expect(t, err == nil, "Failed to load animation")
}
