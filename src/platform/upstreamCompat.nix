{
  src,
  mainFile,
  extraTargets,
  target,
  nixFork,
  nixpkgs,
  config,
  pkgs,
}:

let
  ir = pkgs.lib.mkGestaltIR {
    target = pkgs.gestaltPlatform.targets.${target.name};
    modules = [ ("${src}/${mainFile}") ];
  };

  nestedFile = pkgs.writeText "flake.nix" ''
    {
      inputs = {
        nixpkgs.url = "path:${nixpkgs}";
        gestalt.url = "path:${../..}";
        nixFork.url = "path:${nixFork}";
        gestalt.inputs.nixpkgs.follows = "nixpkgs";
        gestalt.inputs.nixFork.follows = "nixFork";
      };
      outputs = { self, nixpkgs, gestalt, ... }:
      let
        pkgs = import nixpkgs {
          system = "${pkgs.hostPlatform.system}";
          overlays = [
            gestalt.overlays.default
          ];
        };
      in
        {
          packages.${pkgs.hostPlatform.system}.default = pkgs.gestaltPlatform.buildApplication {
            modules = [ ${src}/${mainFile} ];
            target = pkgs.gestaltPlatform.targets.''${"${target.name}"};
            extraTargets = [];
          };
        };
    }
  '';
in

pkgs.stdenv.mkDerivation {
  pname = ir.name;
  version = ir.version;

  inherit null;
  unpackPhase = "true";
  installPhase = ''

    export HOME=$(mktemp -d)
    mkdir sub
    cp ${nestedFile} sub/flake.nix
    cd sub
    ${
      nixFork.packages.${pkgs.stdenv.hostPlatform.system}.default
    }/bin/nix build $pwd --impure --offline --extra-experimental-features 'flakes nix-command pipe-operators' --option flake-registry ""
    ls -lah

    cp -r ./result $out

  '';
  dontFixup = true;

  passthru = {
    extraTargets = builtins.mapAttrs (name: target: 
      config.gestaltPlatform.buildApplication {
        useUpstreamNix = true;
        inherit src mainFile;
        targetName = name;
        extraTargets = {};
      }
    ) extraTargets;
  };

  requiredSystemFeatures = [ "recursive-nix" ];

}
