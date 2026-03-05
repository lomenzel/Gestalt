{
  src,
  mainFile,
  extraTargets,
  target,
  nixFork,
  nixpkgs,
  systems,
  flake-utils,
  nix-appimage,
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
        nix-appimage.url = "path:${nix-appimage}";
        nix-appimage.inputs.nixpkgs.follows = "nixpkgs";
        gestalt.inputs.nix-appimage.follows = "nix-appimage";
        gestalt.inputs.systems.follows = "systems";
        flake-utils.url = "path:${flake-utils}";
        flake-utils.inputs.systems.follows = "systems";
        systems.url = "path:${systems}";
      };
      outputs = { self, nixpkgs, gestalt, ... }:
      let
        pkgs = import nixpkgs {
          system = "${pkgs.stdenv.buildPlatform.system}";
          overlays = [
            gestalt.overlays.default
          ];
        };
      in
        {
          packages.${pkgs.stdenv.buildPlatform.system}.default = pkgs.gestaltPlatform.buildApplication {
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
  dontUnpack = true;
  installPhase = ''

    export HOME=$(mktemp -d)
    mkdir sub
    cp ${nestedFile} sub/flake.nix
    cd sub
    ${
      nixFork.packages.${pkgs.stdenv.buildPlatform.system}.default
    }/bin/nix build -L $pwd --impure --offline --extra-experimental-features 'flakes nix-command pipe-operators' --option flake-registry ""
    ls -lah

    cp -r ./result $out

  '';
  dontFixup = true;

  passthru = {
    extraTargets = builtins.mapAttrs (
      name: target:
      config.gestaltPlatform.buildApplication {
        useUpstreamNix = true;
        inherit src mainFile;
        targetName = name;
        extraTargets = { };
      }
    ) extraTargets;
    publish = pkgs.stdenv.mkDerivation {
      pname = "${ir.name}-publish";
      version = ir.version;
      unpackPhase = "true";
      installPhase = ''

        export HOME=$(mktemp -d)
        mkdir sub
        cp ${nestedFile} sub/flake.nix
        cd sub
        ${
          nixFork.packages.${pkgs.stdenv.buildPlatform.system}.default
        }/bin/nix build -L $pwd\#default.publish --impure --offline --extra-experimental-features 'flakes nix-command pipe-operators' --option flake-registry ""
        ls -lah

        cp -r ./result $out

      '';

      requiredSystemFeatures = [ "recursive-nix" ];
      dontFixup = true;
    };
  };

  requiredSystemFeatures = [ "recursive-nix" ];

}
