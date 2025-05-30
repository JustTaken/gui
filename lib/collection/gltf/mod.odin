package gltf

import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:os"
import "core:path/filepath"

import "core:testing"
import "lib:collection/vector"
import "lib:error"

@(private)
Matrix :: matrix[4, 4]f32

Invertable_Transform :: struct {
  translate: [3]f32,
  scale:     [3]f32,
  rotate:    [4]f32,
  compose:   Matrix,
  inverse:   Matrix,
}

Transform :: struct {
  translate: [3]f32,
  scale:     [3]f32,
  rotate:    [4]f32,
  compose:   Matrix,
}

@(private)
Context :: struct {
  bytes:            []u8,
  dir:              string,
  obj:              json.Object,
  raw_scenes:       json.Array,
  raw_animations:   json.Array,
  raw_buffers:      json.Array,
  raw_buffer_views: json.Array,
  raw_materials:    json.Array,
  raw_meshes:       json.Array,
  raw_skins:        json.Array,
  raw_accessors:    json.Array,
  raw_nodes:        json.Array,
  asset:            Asset,
  accessors:        vector.Vector(Accessor),
  materials:        vector.Vector(Material),
  meshes:           vector.Vector(Mesh),
  nodes:            vector.Vector(Node),
  skins:            vector.Vector(Skin),
  buffers:          vector.Vector(Buffer),
  buffer_views:     vector.Vector(Buffer_View),
  animations:       vector.Vector(Animation),
  scenes:           vector.Vector(Scene),
  allocator:        runtime.Allocator,
}

Gltf :: struct {
  scenes:     vector.Vector(Scene),
  animations: vector.Vector(Animation),
  nodes:      vector.Vector(Node),
  skins:      vector.Vector(Skin),
  meshes:     vector.Vector(Mesh),
  materials:  vector.Vector(Material),
}

from_file :: proc(
  path: string,
  allocator: runtime.Allocator,
) -> (
  gltf: Gltf,
  err: error.Error,
) {
  log.info("Loading Gltf from file path:", path)

  ctx: Context
  ctx.allocator = allocator

  if bytes, ok := os.read_entire_file(path, allocator = ctx.allocator); ok {
    if value, j_err := json.parse(bytes, allocator = ctx.allocator);
       j_err == nil {
      ctx.obj = value.(json.Object)
    } else do return gltf, .GltfLoadFailed
  } else do return gltf, .FileNotFound

  ctx.dir = filepath.dir(path, ctx.allocator)

  parse_asset(&ctx) or_return
  parse_buffers(&ctx) or_return
  parse_buffer_views(&ctx) or_return
  parse_accessors(&ctx) or_return
  parse_materials(&ctx) or_return
  parse_meshes(&ctx) or_return
  parse_skins(&ctx) or_return
  parse_animations(&ctx) or_return
  parse_nodes(&ctx) or_return
  parse_scenes(&ctx) or_return

  gltf.scenes = ctx.scenes
  gltf.materials = ctx.materials
  gltf.meshes = ctx.meshes
  gltf.nodes = ctx.nodes
  gltf.skins = ctx.skins
  gltf.animations = ctx.animations

  return gltf, nil
}

@(private)
transform_apply :: proc(transform: ^Transform) {
  translate := linalg.matrix4_translate(transform.translate)
  rotate := linalg.matrix4_from_quaternion(
    quaternion(
      x = transform.rotate[0],
      y = transform.rotate[1],
      z = transform.rotate[2],
      w = transform.rotate[3],
    ),
  )
  scale := linalg.matrix4_scale(transform.scale)

  transform.compose = translate * rotate * scale
}

@(private)
invertable_transform_apply :: proc(transform: ^Invertable_Transform) {
  translate := linalg.matrix4_translate(transform.translate)
  rotate := linalg.matrix4_from_quaternion(
    quaternion(
      x = transform.rotate[0],
      y = transform.rotate[1],
      z = transform.rotate[2],
      w = transform.rotate[3],
    ),
  )
  scale := linalg.matrix4_scale(transform.scale)

  transform.compose = translate * rotate * scale
  transform.inverse = linalg.inverse(transform.compose)
}

@(test)
first_test :: proc(t: ^testing.T) {
  glt: Gltf
  err: error.Error
  glt, err = from_file("assets/cube_animation.gltf", context.allocator)

  testing.expect(t, err == nil, "Failed to load animation")
}
