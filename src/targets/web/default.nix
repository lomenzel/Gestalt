{ lib, pkgs, ... }:
{
  gestaltPlatform.targets.web = {
    buildApplication =
      ir:
      let
        appJS = pkgs.writeText "${ir.meta.name}-app.js" ''
          ${lib.jsRuntime}
          let app = ${lib.toJS ir}
        '';

        staticSite = pkgs.runCommand "${ir.meta.name}-web" { } ''
          mkdir -p $out
          cp ${./index.html} $out/index.html
          cp ${appJS} $out/app.js
        '';
      in
      pkgs.stdenv.mkDerivation {
        pname = ir.meta.name;
        version = ir.meta.version;
        dontUnpack = true;
        installPhase = ''
          mkdir -p $out/bin $out/share/gestalt-web
          cp -r ${staticSite}/* $out/share/gestalt-web/
          cat > $out/bin/${ir.meta.name} <<'WRAPPER'
          #!/bin/sh
          exec ${pkgs.python3}/bin/python3 -m http.server ''${GESTALT_PORT:-8080} -d ${staticSite}
          WRAPPER
          chmod +x $out/bin/${ir.meta.name}
        '';
        passthru = {
          inherit appJS staticSite;
          devServer = pkgs.writeShellScriptBin "${ir.meta.name}-dev" ''
            export GESTALT_PORT="''${GESTALT_PORT:-3000}"
            export GESTALT_FLAKE_DIR="''${GESTALT_FLAKE_DIR:-.}"
            export GESTALT_APP_ATTR="''${GESTALT_APP_ATTR:-${ir.meta.name}}"
            export GESTALT_WATCH_DIRS="''${GESTALT_WATCH_DIRS:-./examples:./src}"
            export GESTALT_HTML_TEMPLATE="${./index.html}"
            exec ${pkgs.nodejs}/bin/node ${./server.js}
          '';
        };
      };
    effects = (import ../defaultCapabilities.nix).Effects;
    components = {
      displayValue =
        {
          label,
          tooltip ? "",
          value,
          ...
        }@args:
        {
          _type = "displayValue";
          inherit label tooltip value;
        }
        // (if args ? annotations then { inherit (args) annotations; } else { });
      action =
        {
          name,
          tooltip ? "",
          onClick,
          ...
        }@args:
        {
          _type = "action";
          inherit name tooltip onClick;
        }
        // (if args ? annotations then { inherit (args) annotations; } else { });
      actionGroup =
        { actions, ... }:
        {
          _type = "actionGroup";
          # Hand-rolled to avoid pulling lib.mapAttrsToList (and transitively
          # all of lib) into the reified IR.
          actions = map (id: actions.${id} // { inherit id; }) (builtins.attrNames actions);
        };
      section = x: x;
    };
    module = ../../lib/standardPageView.nix;
  };
}
