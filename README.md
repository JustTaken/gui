# Generate wayland interfaces
```bash
odin run scan -- <output-path.odin> <odin-output-package-name>" # generate know wayland protocol types in odin style
odin run scan -- <path-to-wayland.xml> <output-path.odin> <wayland-interface-array-name> <odin-output-package-name>" # generate odin file based on wayland.xml
odin run scan -- <path-to-xdg-shell.xml> <output-path.odin> <xdg-interface-array-name> <odin-output-package-name>" # generate odin file based on xdg-shell.xml
```
## examples
This is the command used to generate `window/wayland/wayland.odin`
```bash
odin run scan -- assets/xml/wayland.xml window/wayland/wayland.odin WAYLAND_INTERFACES protocol
```

This is the command used to generate `window/wayland/interface.odin`
```bash
odin run scan -- window/wayland/interface.odin protocol
```
# Run
```bash
odin run src
```
