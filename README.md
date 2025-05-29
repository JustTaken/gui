# Dependencies
 - odin
 - vulkan-loader
 - vulkan-validation-layers (mandatory for now)
 - shaderc (shader compiler - glslc)

## Generate wayland interfaces
```bash
odin run lib/scan -- "<types-output-path.odin>" "<odin-output-package-name>"
odin run lib/scan -- "<path-to-wayland.xml>" "<wayland-interfaces-output-path.odin>" "<wayland-interface-array-name>" "<odin-output-package-name>"
odin run lib/scan -- "<path-to-xdg-shell.xml>" "<xdg-interfaces-output-path.odin>" "<xdg-interface-array-name>" "<odin-output-package-name>"
odin run lib/scan -- "<path-to-dma-buf.xml>" "<dma-interfaces-output-path.odin>" "<dma-interface-array-name>" "<odin-output-package-name>"
```

### Examples
This is the command used to generate `lib/wayland/interface_wayland.odin`
```bash
odin run lib/scan -- assets/xml/wayland.xml lib/wayland/interface_wayland.odin WAYLAND_INTERFACES protocol
```

This is the command used to generate `lib/wayland/interface.odin`
```bash
odin run lib/scan -- lib/wayland/interface.odin protocol
```

## Compile Shaders
Fow now this is required to be done manually

```bash
glslc assets/shader/boned.vert -o assets/output/boned.spv
glslc assets/shader/unboned.vert -o assets/output/unboned.spv
glslc assets/shader/shader.frag -o assets/output/frag.spv
```

# Run
First compile the [shaders](#compile-shaders) then:

```bash
odin run gui -collection:lib=lib
```
