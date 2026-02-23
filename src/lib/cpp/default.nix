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
          unitTests = ir.unitTests;
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
              "%unitTests%"
              "%meta%"
            ]
            [
              constructorParam.initialState
              constructorParam.actions
              constructorParam.view
              constructorParam.actionParams
              constructorParam.unitTests
              constructorParam.meta
            ]
        |> pkgs.writeText "core.cpp";
    in
    pkgs.stdenv.mkDerivation {
      pname = "libgestalt";
      version = "0.1.0";
      src = null;
      dontUnpack = true;

      buildInputs = [ pkgs.nlohmann_json];

      postPatch = ''
        cp ${header} core.hpp
        cp ${source} core.cpp
      '';

      buildPhase = ''
        g++ -O3 -c core.cpp -o core.o
        ar rcs libgestalt.a core.o
      '';

      checkPhase = ''
        echo "Running unit tests..."

        cat > unitTests.cpp <<'EOF'
#include "core.hpp"
#include <iostream>
int main() {
  GestaltCore core;
  core.runUnitTests();
  std::cout << "All tests passed!" << std::endl;
  return 0;
}
EOF

        g++ -O3 unitTests.cpp libgestalt.a -o unitTests
        ./unitTests
      '';

      doCheck = true;

      installPhase = ''
        mkdir -p $out/include $out/lib
        cp libgestalt.a $out/lib/
        cp core.hpp $out/include/
      '';
      passthru = {
        inherit header source;
      };
    };
}
