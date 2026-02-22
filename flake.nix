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
          cpp-example = pkgs.writeText "test.cpp" ''
            ${pkgs.lib.cppTypeDef}
            GestaltNixValue sum = ${let sum = x: if x <= 0 then 0 else x + (sum (x - 1)); in pkgs.lib.toCpp sum};

            GestaltNixValue five = ${pkgs.lib.toCpp 5};

            GestaltNixValue fifteen = sum(five);

          '';
        }
      );
    };
}
