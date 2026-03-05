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
      overlays.default =
        final: prev:
        let
          nix-appimage-packages = (import inputs.nix-appimage.inputs.nixpkgs {
            localSystem = final.stdenv.buildPlatform;
            crossSystem = final.stdenv.hostPlatform;
          }).pkgsStatic;
        in
        {
          lib =
            prev.lib
            // (import ./src/lib {
              pkgs = prev;
            })
            // ({
              mkAppImage = final.callPackage "${inputs.nix-appimage}/mkAppImage.nix" {
                mkappimage-runtime =
                  nix-appimage-packages.callPackage "${inputs.nix-appimage}/runtimes/appimage-type2-runtime"
                    { };
                mkappimage-apprun =
                  nix-appimage-packages.callPackage "${inputs.nix-appimage}/appruns/userns-chroot"
                    { };
              };
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
          pkgs = (
            import nixpkgs {
              inherit system;
              #system = "aarch64-linux";
              overlays = [ self.overlays.default ];
            }
          );
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
