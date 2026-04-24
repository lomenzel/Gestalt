{ lib, pkgs, ... }:
{
  gestaltPlatform.targets.test = {
    buildApplication =
      ir:
      let appLib = 
      (lib.mkCppLibrary {
        value = ir;
        namespace = "app";
      }).mkDerivation
        pkgs;
        in 
        pkgs.stdenv.mkDerivation (finalAttrs:{
          pname = ir.meta.name;
          version = ir.meta.version;
          src = ./.;
          buildInputs = [ appLib ];
          makeFlags = [ "APP_NAME=${finalAttrs.pname}" ];
        })
        ;
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
