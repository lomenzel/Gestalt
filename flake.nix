{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixFork.url = "github:lomenzel/nix";
    nix-appimage.url = "github:ralismark/nix-appimage";
    nix-appimage.inputs.nixpkgs.follows = "nixpkgs";
    nix-appimage.inputs.flake-utils.follows = "flake-utils";
    flake-utils.url = "github:numtide/flake-utils";
    systems.url = "github:nix-systems/default";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    wechselbalg = {
      type = "git";
      url = "https://rad-node.menzel.lol/rad:zpRitanyyPyavYSf6RWXeXry864M.git";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
      wechselbalg,
      ...
    }@inputs:
    let
      eachSystem =
        f:
        nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
          system:
          f {
            inherit system;
            pkgs = import nixpkgs {
              inherit system;
              overlays = [
                wechselbalg.overlays.default
                self.overlays.default
              ];
            };
          }
        );
      treefmtEval = eachSystem ({ pkgs, ... }: treefmt-nix.lib.evalModule pkgs ./treefmt.nix);
    in
    {
      overlays.default =
        final: prev:
        let
          nix-appimage-packages =
            (import inputs.nix-appimage.inputs.nixpkgs {
              localSystem = final.stdenv.buildPlatform;
              crossSystem = final.stdenv.hostPlatform;
            }).pkgsStatic;
        in
        {
          lib =
            prev.lib
            // import ./src/lib {
              inherit (final) lib;
            };
        }
        // {
          gestaltPlatform = (
            import ./src/platform {
              pkgs = final;
              inherit inputs;
            }
          );
        };

      devShells = eachSystem (
        { system, pkgs }:
        {
          default = pkgs.mkShell {
            buildInputs = [
              inputs.nixFork.packages.${system}.nix
              pkgs.nodejs
              pkgs.clang
              pkgs.nixd
            ];
          };
        }
      );

      # example usage
      packages = eachSystem (
        { system, pkgs, ... }:

        {

          counter = pkgs.gestaltPlatform.buildApplication {
            src = ./examples/counter;
          };

        }
      );

      # for `nix fmt`
      formatter = eachSystem ({ system, ... }: treefmtEval.${system}.config.build.wrapper);
      # for `nix flake check`

      checks = eachSystem (
        { system, pkgs, ... }:

        self.packages.${system}
        // {
          fmt = treefmtEval.${system}.config.build.check self;
        }
      );
    };
}
