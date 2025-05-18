package gltf

import "base:runtime"
import "core:os"
import "core:log"
import "core:encoding/json"
import "core:fmt"
import "core:path/filepath"

import "core:testing"
import "./../../error"

@private
Matrix :: matrix[4, 4]f32

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
  fragmented_animations: []Animation_Fragmented,
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

  if bytes, ok := os.read_entire_file(path); ok {
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

// @private
// greater :: proc(first, second: f32) -> bool {
//   return first > second + 0.001
// }

// @private
// show_primitive :: proc(primitive: Mesh_Primitive) {
//   for accessor in primitive.accessors {
//     if accessor == nil do continue

//     log.info("    Kind", accessor.component_kind)
//     log.info("    Count", accessor.component_count)
//     log.info("    Len", accessor.count)
//   }
// }

// @private
// show_mesh :: proc(mesh: ^Mesh) {
//   log.info("Mesh:", mesh.name)

//   for primitive in mesh.primitives {
//     show_primitive(primitive)
//   }
// }

// @private
// show_joint :: proc(joint: ^Node) {
//   log.info("  Joint", rawptr(joint), joint.name, joint.transform)
// }

// @private
// show_skin :: proc(skin: ^Skin) {
//   for joint in skin.joints {
//     show_joint(joint)
//   }
// }

// @private
// show_node :: proc(node: ^Node) {
//   if mesh := node.mesh; mesh != nil {
//     show_mesh(mesh)
//   }

//   if skin := node.skin; skin != nil {
//     show_skin(skin)
//   }

//   for child in node.children {
//     show_node(child)
//   }
// }

@test
first_test :: proc(t: ^testing.T) {
  glt: Gltf
  err: error.Error
  glt, err = from_file("assets/cube_animation.gltf", context.allocator)

  // scene := glt.scenes["Scene"]

  // for &node, i in scene.nodes {
  //   show_node(node)
  // }

  testing.expect(t, err == nil, "Failed to load animation")
}
