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
        vulkan-validation-layers
        shaderc
        feh
      ];

      LD_LIBRARY_PATH = "${pkgs.vulkan-loader}/lib:${pkgs.vulkan-validation-layers}";
    };
  };
}
