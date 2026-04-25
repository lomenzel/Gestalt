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
        nativeBuildInputs = with pkgs; [
          kdePackages.wrapQtAppsHook
          kdePackages.extra-cmake-modules
        ];
        buildInputs = [
          appLib
        ]
        ++ (
          with pkgs;
          with kdePackages;
          [
            qtdeclarative
            cmake
            kirigami
            ninja
            kcoreaddons
          ]
        );
        APP_TITLE = ir.meta.title;
        APP_NAME = ir.meta.name;
        APP_LIB_PATH = "${appLib}";
      });
    effects = (import ../defaultCapabilities.nix).Effects;
    components = {
      displayValue =
        {
          label,
          tooltip ? "",
          value,
          ...
        }:
        {
          _type = "displayValue";
          inherit label tooltip value;
        };
      action =
        {
          name,
          tooltip ? "",
          onClick,
          ...
        }:
        {
          _type = "action";
          inherit name tooltip onClick;
        };
      actionGroup =
        { actions, ... }:
        {
          _type = "actionGroup";
          actions = lib.mapAttrsToList (id: a: a // { inherit id; }) actions;
        };
      section = x: x;
    };
    module = ./module.nix;
  };
}
