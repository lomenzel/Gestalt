{
  src,
  mainFile,
  target,
  extraTargets ? { },
  nixFork,
  nixpkgs,
  pkgs,
  wechselbalg,
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
  inherit (pkgs) lib;

  collectInputs =
    prefix: inputs:
    collectInputs' prefix inputs { }
    |> map ({ name, path }: " --override-input ${name} path:${path} ")
    |> lib.concatStringsSep "";

  collectInputs' =
    prefix: inputs: visitedPaths:
    builtins.trace "collecting inputs for: ${prefix}" (
      lib.attrsToList (lib.removeAttrs inputs [ "self" ])
      |> map (
        { name, value }:
        let
          path = if builtins.hasAttr "outPath" value then toString value.outPath else toString value;
        in
        if (builtins.hasAttr (builtins.unsafeDiscardStringContext path) visitedPaths) then
          [ ]
        else
          [
            {
              name = "${prefix}/${name}";
              inherit path;
            }
          ]
          ++ (lib.optional (builtins.hasAttr "inputs" value) (
            collectInputs' "${prefix}/${name}" value.inputs (
              visitedPaths // { ${builtins.unsafeDiscardStringContext path} = true; }
            )
          ))
      )
      |> lib.flatten
    );
  flake = pkgs.writeText "flake.nix" ''
    {
      inputs = {
        nixpkgs.url = "path:${nixpkgs.outPath}";
        core.url = "path:${self.outPath}";
        target.url = "path:${target.input.outPath}";

      };
      outputs = { self, nixpkgs, core, target, ... }:
        let
          pkgs = import nixpkgs {
            system = "${pkgs.stdenv.buildPlatform.system}";
            overlays = [
              core.overlays.default
              target.overlays.default
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
    }/bin/nix build -L $pwd --impure --offline --extra-experimental-features 'flakes nix-command pipe-operators' --option flake-registry "" \
      ${collectInputs "core" inputs} ${collectInputs "target" target.input.inputs}
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
