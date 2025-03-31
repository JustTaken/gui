# Dependencies
 - odin
 - vulkan-loader
 - vulkan-validation-layers (mandatory for now)
 - shaderc (shader compiler - glslc)

## Generate wayland interfaces
```bash
odin run scan -- <types-output-path.odin> <odin-output-package-name>
odin run scan -- <path-to-wayland.xml> <wayland-interfaces-output-path.odin> <wayland-interface-array-name> <odin-output-package-name>
odin run scan -- <path-to-xdg-shell.xml> <xdg-interfaces-output-path.odin> <xdg-interface-array-name> <odin-output-package-name>
```

### Examples
This is the command used to generate `window/wayland/wayland.odin`
```bash
odin run scan -- assets/xml/wayland.xml window/wayland/wayland.odin WAYLAND_INTERFACES protocol
```

This is the command used to generate `window/wayland/interface.odin`
```bash
odin run scan -- window/wayland/interface.odin protocol
```

## Compile Shaders
Fow now this is required to be done manually

```bash
glslc assets/shader/shader.vert -o assets/output/vert.spv
glslc assets/shader/shader.frag -o assets/output/frag.spv
```

# Run
```bash
odin run src
```

