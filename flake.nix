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
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
      ...
    }@inputs:
    let
      eachSystem = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
      treefmtEval = eachSystem (
        system: treefmt-nix.lib.evalModule (import nixpkgs { inherit system; }) ./treefmt.nix
      );
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

      devShells = eachSystem (system:
      {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          buildInputs = [
            inputs.nixFork.packages.${system}.nix
          ];
        };
      });

      # example usage
      packages = eachSystem (
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

          performance-metrics = import ./benchmarks {
            inherit pkgs;
          };

        }
      );

      # for `nix fmt`
      formatter = eachSystem (system: treefmtEval.${system}.config.build.wrapper);
      # for `nix flake check`

      checks = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in
        self.packages.${system}
        // {
          fullPublishExample = self.packages.${system}.practiceHelper.publish;
          fmt = treefmtEval.${system}.config.build.check self;
          translation = import ./tests/translators/default.nix { inherit pkgs; };
        }
      );
    };
}
