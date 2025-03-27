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
      ];

      LD_LIBRARY_PATH = "${pkgs.vulkan-loader}/lib";
      CPLUS_INCLUDE_PATH = "${pkgs.glibc.dev}/include";
    };
  };
}
