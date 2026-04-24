{ lib, pkgs, ... }:
{
  gestaltPlatform.targets.kirigami = {
    buildApplication =
      ir:
      let
        appLib =
          (lib.mkCppLibrary {
            value = ir;
            namespace = "app";
          }).mkDerivation
            pkgs;
      in
      pkgs.stdenv.mkDerivation (finalAttrs: {
        pname = ir.meta.name;
        version = ir.meta.version;
        src = ./.;
        nativeBuildInputs = [
          #appLib
          pkgs.kdePackages.wrapQtAppsHook
        ];
        buildInputs =
          with pkgs;
          with kdePackages;
          [
            qtdeclarative
            cmake
            kirigami
            ninja
            kcoreaddons
          ];
          APP_TITLE = ir.meta.title;
          APP_NAME = ir.meta.name;
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
