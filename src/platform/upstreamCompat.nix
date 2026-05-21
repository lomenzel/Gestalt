{
  src,
  mainFile,
  target,
  extraTargets ? { },
  nixFork,
  nixpkgs,
  pkgs,
  wechselbalg,
  kirigami-target,
  inputs,
  self,
  buildApplication,
  ...
}:
let
  ir = pkgs.lib.mkGestaltIR {
    target = pkgs.gestaltPlatform.targets.${builtins.trace target target.name};
    modules = [ "${src}/${mainFile}" ];
  };
  flake = pkgs.writeText "flake.nix" ''
    {
      inputs = {
        nixpkgs.url = "path:${nixpkgs}";
        wechselbalg.url = "path:${wechselbalg}";
        gestalt.url = "path:${self}";
        gestalt.inputs.kirigami-target.follows = "kirigami-target";
        gestalt.inputs.web-target.follows = "web-target";
        kirigami-target = {
          flake = false;
          url = "path:${kirigami-target}";
        };
        web-target = {
          flake = false;
          url = "path:${inputs.web-target}";
        };

      };
      outputs = { self, nixpkgs, gestalt, wechselbalg, ... }:
        let
          pkgs = import nixpkgs {
            system = "${pkgs.stdenv.buildPlatform.system}";
            overlays = [
              gestalt.overlays.default
              wechselbalg.overlays.default
            ];
          };
        in
        {
          packages.${pkgs.stdenv.buildPlatform.system}.default = pkgs.gestaltPlatform.buildApplication {
            src = "${src}";
            mainFile = "${mainFile}";
            target = pkgs.gestaltPlatform.targets.${target.name};
          };
        };

    }
  '';
in
pkgs.stdenv.mkDerivation {
  pname = ir.meta.name;
  version = "${ir.meta.version}-upstreamCompat-${target.name}";
  dontUnpack = true;
  installPhase = ''
    export HOME=$(mktemp -d)
    mkdir sub
    cp ${flake} sub/flake.nix
    cd sub
    ${
      nixFork.packages.${pkgs.stdenv.buildPlatform.system}.default
    }/bin/nix build -L $pwd --impure --offline --extra-experimental-features 'flakes nix-command pipe-operators' --option flake-registry ""
    ls -lah
    cp -r ./result $out
  '';
  passthru =
    let
      buildPassthru =
        attrName:
        pkgs.stdenv.mkDerivation {
          name = "${ir.meta.name}-${if attrName == "devServer" then "dev" else attrName + "-upstreamCompat"}";
          version = ir.meta.version;
          dontUnpack = true;
          installPhase = ''
            export HOME=$(mktemp -d)
            mkdir sub
            cp ${flake} sub/flake.nix
            cd sub
            ${
              nixFork.packages.${pkgs.stdenv.buildPlatform.system}.default
            }/bin/nix build .#default.${attrName} -L $pwd --impure --offline --extra-experimental-features 'flakes nix-command pipe-operators' --option flake-registry ""
            ls -lah
            cp -r ./result $out
          '';
          dontFixup = true;
          requiredSystemFeatures = [ "recursive-nix" ];
        };
    in
    {
      extraTargets = builtins.mapAttrs (
        _: t:
        buildApplication {
          inherit src mainFile;
          target = t;
        }
      ) extraTargets;
      devServer = buildPassthru "devServer";
      publish = buildPassthru "publish";
      appJS = buildPassthru "appJS";
      screenshot = buildPassthru "screenshot";
    };
  dontFixup = true;
  requiredSystemFeatures = [ "recursive-nix" ];
}
