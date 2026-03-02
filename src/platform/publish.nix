{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  gestaltPlatform.publish =
    modules:
    let
      inherit (config.gestaltPlatform) buildApplication;
      webIR = lib.mkGestaltIR {
        target = config.gestaltPlatform.targets.web;
        modules = modules;
      };
      web = buildApplication {
        inherit modules;
        target = config.gestaltPlatform.targets.web;
      };
      tui = buildApplication {
        inherit modules;
        target = config.gestaltPlatform.targets.tui;
      };

      fullTarget = {
        inherit (config.gestaltPlatform.targets.web) capabilities;
        buildApplication =
          ir:
          pkgs.runCommand "full-build" { } ''
            mkdir -p $out/app
            cp -r ${web}/public/* $out/app
            cp ${
              pkgs.writeText "" (
                builtins.readFile ./landing.html
                |> builtins.replaceStrings [ "%appname%" "%apptitle%" ] [ webIR.name webIR.title ]
              )
            } $out/index.html

            mkdir -p $out/download
            (cd ${web}/public && ${pkgs.zip}/bin/zip -r $out/download/${webIR.name}.zip .)
            cp ${lib.mkAppImage { program = "${tui}/bin/${webIR.name}"; }} $out/download/${webIR.name}.AppImage
            cp ${
              (tui.override (old: {
                ir = old.ir // {
                  initialState = old.ir.showcaseState;
                };
              })).screenshot
            }/screenshot.png $out/download/${webIR.name}-tui.png
            cp ${
              (web.override (old: {
                ir = old.ir // {
                  initialState = old.ir.showcaseState;
                };
              })).screenshot
            }/screenshot.png $out/download/${webIR.name}-web.png
          '';
      };
      full = config.gestaltPlatform.buildApplication {
        inherit modules;
        target = fullTarget;
      };
    in
    pkgs.stdenv.mkDerivation {
      dontUnpack = true;
      name = "${webIR.name}-publish";

      installPhase = ''
        mkdir -p $out

        ln -s ${full} $out/public

        mkdir -p $out/bin
        cp ${pkgs.writeShellScript "publish" ''
                    set -euo pipefail

          if ! cid=$(${pkgs.kubo}/bin/ipfs add --cid-version=1 -r --quiet ${full} | tail -n1); then
            echo "" >&2
            echo -e "\033[31m[Error] Failed to publish to IPFS\033[0m" >&2
            echo "This framework uses IPFS (InterPlanetary File System) to host and publish your application." >&2
            echo "If you haven't set up IPFS yet, please ensure the IPFS daemon is running." >&2
            echo "refer to https://wiki.nixos.org/wiki/IPFS" >&2
            exit 1
          fi

          echo "You can access your application now on ipfs://''${cid}"
          ''} $out/bin/${webIR.name}-publish
      '';
    };
}
