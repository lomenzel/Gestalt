{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
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
    web-target = {
      flake = false;
      type = "git";
      url = "https://rad-node.menzel.lol/rad:zCfRPjVLN6H9TqATGjMspb86p1ZZ.git";
    };
    kirigami-target = {
      flake = false;
      type = "git";
      url = "https://rad-node.menzel.lol/rad:z22uYeGHbYxD14pCZyzWi4577Vej7.git";
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


      formatter = eachSystem ({ system, ... }: treefmtEval.${system}.config.build.wrapper);

      checks = eachSystem (
        { system, pkgs, ... }:

        self.packages.${system}
        // {
          fmt = treefmtEval.${system}.config.build.check self;
        }
      );

    };
}
