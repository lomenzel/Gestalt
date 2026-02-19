{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix = {
      url = "github:lomenzel/nix";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      nix,
    }@inputs:
    flake-utils.lib.eachDefaultSystem (system:
    let 
      lib = self.lib.${system};
      pkgs = import nixpkgs { inherit system; };
    in {
      lib = import ./src/lib {
        pkgs = import nixpkgs { system = "x86_64-linux"; };
      };
      packages =  {
        examples = builtins.readDir ./examples
          |> pkgs.lib.mapAttrs (example: _:
            pkgs.lib.mapAttrs (_: target:
              lib.buildGestaltApplication (
                (import (./examples + "/${example}")) // {
                  inherit target;
                }
              )
            ) lib.targets
        );
        compatExample = import ./src/lib/upstreamNixCompatibilityWrapper.nix {
          src = ./examples/minimal;
          inherit nixpkgs pkgs;
          gestaltSrc = self;
          nix = nix.packages.${pkgs.system}.default;
        };
      };

    });
}
