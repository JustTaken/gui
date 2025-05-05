#+private
package collection

import "core:encoding/json"

Gltf_Asset :: struct {
  generator: string,
  version: string,
}

parse_asset :: proc(ctx: ^Gltf_Context) -> (asset: Gltf_Asset, err: Error) {
  raw := ctx.obj["asset"].(json.Object)

  asset.generator = raw["generator"].(string)
  asset.version = raw["version"].(string)

  return asset, nil
}
