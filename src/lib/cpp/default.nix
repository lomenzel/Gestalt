{ lib, config, pkgs, ... }:
{
  imports = [
    ./toCpp.nix
  ];
  lib.gestaltCore.cpp =
    ir:
    let
      constructorParam =
        {
          actions = builtins.mapAttrs (name: action: action.function) ir.actions;
          inherit (ir) view initialState;
          meta = {
            inherit (ir)
              name
              title
              version
              author
              ;
          };
          actionParams = builtins.mapAttrs (
            _: action:
            let
              paramType =
                if builtins.hasAttr "paramType" action && builtins.typeOf action.paramType == "set" then
                  action.paramType
                else
                  null;
              fields = if paramType != null && builtins.hasAttr "fields" paramType then paramType.fields else { };
              innerFields =
                if
                  builtins.hasAttr "params" fields
                  && builtins.typeOf fields.params == "set"
                  && builtins.hasAttr "fields" fields.params
                then
                  fields.params.fields
                else
                  fields;
            in
            builtins.attrNames innerFields
          ) ir.actions;
        }
        |> builtins.mapAttrs (_: v: config.lib.toCpp v);
      header = ./core.hpp;
      source =
        builtins.readFile ./core.cpp
        |>
          builtins.replaceStrings
            [
              "%initialState%"
              "%actions%"
              "%view%"
              "%actionParams%"
              "%meta%"
            ]
            [
              constructorParam.initialState
              constructorParam.actions
              constructorParam.view
              constructorParam.actionParams
              constructorParam.meta
            ]
        |> pkgs.writeText "core.cpp";
    in
    pkgs.stdenv.mkDerivation {
      pname = "libgestalt";
      version = "0.1.0";
      src = null;
      dontUnpack = true;

      postPatch = ''
        cp ${header} core.hpp
        cp ${source} core.cpp
      '';

      buildPhase = ''
        $CXX -O3 -c core.cpp -o core.o
        $AR rcs libgestalt.a core.o
      '';

      installPhase = ''
        mkdir -p $out/include $out/lib
        cp libgestalt.a $out/lib/
        cp core.hpp $out/include/
      '';
    };
}
