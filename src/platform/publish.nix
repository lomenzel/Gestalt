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
            cp ${pkgs.writeText "" (builtins.readFile ./landing.html |> builtins.replaceStrings ["%appname%" "%apptitle%"] [webIR.name webIR.title])} $out/index.html

            mkdir -p $out/download
            (cd ${web}/public && ${pkgs.zip}/bin/zip -r $out/download/${webIR.name}.zip .)
            cp ${lib.mkAppImage {program = "${tui}/bin/${webIR.name}"; }} $out/download/${webIR.name}.AppImage
            cp ${tui.screenshot}/screenshot.png $out/download/${webIR.name}-tui.png
            cp ${web.screenshot}/screenshot.png $out/download/${webIR.name}-web.png
          '';
      };
      full = config.gestaltPlatform.buildApplication {
        inherit modules;
        target = fullTarget;
      };
    in
    pkgs.writeShellScriptBin "publish" ''
      set -euo pipefail

      cid=$(ipfs add --cid-version=1 -r --quiet ${full} | tail -n1)

      echo "You can access your application now on ipfs://''${cid}"
    '';
}
