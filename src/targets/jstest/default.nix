{ lib, pkgs, ... }:
{
  gestaltPlatform.targets.jstest = {
    buildApplication =
      ir:
      pkgs.stdenv.mkDerivation (finalAttrs: {
        pname = ir.meta.name;
        version = ir.meta.version;
        #src = ./.;
        dontUnpack = true;
        installPhase = ''
          mkdir -p $out/bin
          cp ${pkgs.writeShellScript ir.meta.name ''
            ${pkgs.nodejs}/bin/node ${pkgs.writeText "app.js" ''
              ${lib.jsRuntime}
              let app = ${lib.toJS ir}
              console.log("Hello, World!");
              console.log(app);
              console.log(app.asSet().exampleView.asString());
              console.log(app.asSet().view.call(app.asSet().initialState).asString());

            ''}
          ''} $out/bin/${ir.meta.name}

        '';
        buildInputs = [
          #appLib
        ];
        #makeFlags = [ "APP_NAME=${finalAttrs.pname}" ];
      });
    effects = (import ../defaultCapabilities.nix).Effects;
    components = {
      actionGroup = x: { };
      displayValue = x: { };
      action = x: { };
      section = x: { };
    };
    module = ./module.nix;
  };
}
