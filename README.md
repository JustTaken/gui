# Generate wayland interfaces
```bash
odin run scan -- <output-path.odin> <odin-output-package-name>
odin run scan -- <path-to-wayland.xml> <output-path.odin> <wayland-interface-array-name> <odin-output-package-name>
odin run scan -- <path-to-xdg-shell.xml> <output-path.odin> <xdg-interface-array-name> <odin-output-package-name>
```
## Examples
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
