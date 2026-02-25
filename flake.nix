{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixFork.url = "github:lomenzel/nix";
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
          });
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
          practiceHelper = pkgs.gestaltPlatform.buildGestaltApplication {
            src = ./examples/practiceHelper;
            target = pkgs.gestaltPlatform.targets.web;
            extraTargets = pkgs.gestaltPlatform.targets;
          };
          counter = pkgs.gestaltPlatform.buildGestaltApplication {
            src = ./examples/counter;
          };
          http = pkgs.gestaltPlatform.buildGestaltApplication {
            src = ./examples/http;
           };

        }
      );
    };
}
