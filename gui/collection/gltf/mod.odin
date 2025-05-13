package gltf

import "base:runtime"
import "core:os"
import "core:log"
import "core:encoding/json"
import "core:path/filepath"
import "core:fmt"

import "./../../error"

Matrix :: matrix[4, 4]f32

Gltf_Context :: struct {
  obj: json.Object,

  raw_meshes: json.Array,
  raw_buffer_views: json.Array,
  raw_materials: json.Array,

  accessors: []Gltf_Accessor,
  nodes: []Gltf_Node,
  skins: []Gltf_Skin,
  buffers: []Gltf_Buffer,
  allocator: runtime.Allocator,
  tmp_allocator: runtime.Allocator,
}

Gltf :: struct {
  scenes: map[string]Gltf_Scene,
  animations: map[string]Gltf_Animation,
}

gltf_from_file :: proc(path: string, allocator: runtime.Allocator, tmp_allocator: runtime.Allocator) -> (gltf: Gltf, err: error.Error) {
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

  ctx.raw_buffer_views = ctx.obj["bufferViews"].(json.Array)
  ctx.raw_meshes = ctx.obj["meshes"].(json.Array)

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

  asset := parse_asset(&ctx) or_return
  ctx.accessors = parse_accessors(&ctx) or_return
  ctx.nodes = parse_nodes(&ctx) or_return
  gltf.scenes = parse_scenes(&ctx) or_return

  if ctx.skins, err = parse_skins(&ctx); err != nil {
    log.info("No skin found")
  }

  if gltf.animations, err = parse_animations(&ctx); err != nil {
    log.info("No animations found")
  }

  for buffer in ctx.buffers {
    if os.close(buffer.fd) != nil do return gltf, .FileNotFound
  }

  return gltf, nil
}

greater :: proc(first, second: f32) -> bool {
  return first > second + 0.001
}
