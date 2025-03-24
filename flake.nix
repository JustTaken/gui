{
  outputs = { self, nixpkgs }:
  let system = "x86_64-linux"; in
  let pkgs = import nixpkgs { inherit system; };
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        odin
        ols
        vulkan-loader
        glfw
        shaderc
        helix
        wayland
        wayland.dev
        wayland-scanner
      ];

      LD_LIBRARY_PATH = "${pkgs.vulkan-loader}/lib:${pkgs.glfw}/lib:${pkgs.wayland}/lib";
      C_INCLUDE_PATH = "${pkgs.wayland.dev}/include";
    };
  };
}
