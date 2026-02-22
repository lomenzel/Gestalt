{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
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
            modules = [ ./examples/practiceHelper/default.nix ];
          };
          counter = pkgs.gestaltPlatform.buildGestaltApplication {
            modules = [ ./examples/counter/default.nix ];
          };
          mensa = pkgs.gestaltPlatform.buildGestaltApplication {
            modules = [ ./examples/mensa/default.nix];
          };
          http = pkgs.gestaltPlatform.buildGestaltApplication {
            modules = [ ./examples/http/default.nix];
           };
          cpp-example = pkgs.lib.gestaltCore.cpp (
            pkgs.lib.mkGestaltIR {
              modules = [ ./examples/counter/default.nix ];
              target = pkgs.gestaltPlatform.targets.cli;
            }
          );
        }
      );
    };
}
