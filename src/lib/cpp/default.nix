{
  lib,
  config,
  pkgs,
  ...
}:
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
          initialEffect = ir.initialEffect;
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
              "%initialEffect%"
            ]
            [
              constructorParam.initialState
              constructorParam.actions
              constructorParam.view
              constructorParam.actionParams
              constructorParam.unitTests
              constructorParam.meta
              constructorParam.initialEffect
            ]
        |> pkgs.writeText "core.cpp";
    in
    pkgs.stdenv.mkDerivation {
      pname = "libgestalt-cpp";
      version = "0.1.0";
      src = null;
      dontUnpack = true;

      buildInputs = [ pkgs.nlohmann_json ];

      postPatch = ''
        cp ${header} core.hpp
        cp ${source} core.cpp
      '';

      buildPhase = ''
        $CXX -O3 -c core.cpp -o core.o
        $AR rcs libgestalt.a core.o
      '';

      checkPhase = pkgs.writeShellScript "check" ''
        echo "Compiling unit tests..."

        cat > unitTests.cpp <<'EOF'
        #include "core.hpp"
        #include <iostream>

        using Value = GestaltCore::Value;
        int main() {
          GestaltCore::runUnitTests(${constructorParam.unitTests});
          std::cout << "All tests passed!" << std::endl;
          return 0;
        }
        EOF

        $CXX -O3 unitTests.cpp libgestalt.a -o unitTests

        echo "Running unit tests..."
        ${pkgs.stdenv.hostPlatform.emulator pkgs.buildPackages} ./unitTests
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
