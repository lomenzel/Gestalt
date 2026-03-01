{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixFork.url = "github:lomenzel/nix";
    nix-appimage.url = "github:ralismark/nix-appimage";
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }@inputs:
    {
      overlays.default = final: prev: {
        lib =
          prev.lib
          // (import ./src/lib {
            pkgs = prev;
          }) // {
            mkAppImage = inputs.nix-appimage.lib.${prev.stdenv.hostPlatform.system}.mkAppImage;
          };
        gestaltPlatform = (
          import ./src/platform {
            pkgs = final;
            inherit inputs;
          }
        );
      };

      # example usage
      packages = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in
        {
          practiceHelper = pkgs.gestaltPlatform.buildApplication {
            src = ./examples/practiceHelper;
            target = pkgs.gestaltPlatform.targets.web;
            extraTargets = pkgs.gestaltPlatform.targets;
          };
          counter = pkgs.gestaltPlatform.buildApplication {
            src = ./examples/counter;
          };
          http = pkgs.gestaltPlatform.buildApplication {
            src = ./examples/http;
          };
          minimal = pkgs.gestaltPlatform.buildApplication {
            src = ./examples/minimal;
          };

        }
      );
    };
}
