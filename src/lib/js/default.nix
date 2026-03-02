{
  lib,
  pkgs,
  config,
  ...
}:
{
  imports = [
    ./toJS.nix
  ];

  lib.gestaltCore.js =
    ir:

    let
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
      constructorParam = {
        actions = builtins.mapAttrs (name: action: action.function) ir.actions;
        initialState = ir.initialState;
        inherit actionParams;
        inherit (ir)
          view
          initialEffect
          name
          version
          author
          ;
      };
      coreJS = pkgs.writeText "gestaltCore.js" (
        builtins.readFile ./core.js
        |>
          lib.replaceStrings
            [
              "'%initialState%'"
              "'%actions%'"
              "'%view%'"
              "'%actionParams%'"
              "'%initialEffect%'"
              "'%name%'"
              "'%version%'"
              "'%authorName%'"
            ]
            (
              lib.map config.lib.toJS (
                with constructorParam;
                [
                  initialState
                  actions
                  view
                  actionParams
                  initialEffect
                  name
                  version
                  author.name
                ]
              )
            )
      );
    in
    pkgs.stdenv.mkDerivation {
      pname = "libgestalt-js";
      version = ir.version;
      dontUnpack = true;

      checkPhase = ''
        echo "Running unit tests..."

        ${pkgs.buildPackages.nodejs}/bin/node ${pkgs.writeText "unitTests.js" ''
          import GestaltCore from "${coreJS}";

          GestaltCore.runUnitTests(${config.lib.toJS ir.unitTests});
        ''}

        echo "All tests passed!"
      '';
      doCheck = true;

      installPhase = ''
        cp ${coreJS} $out
      '';
    };

}
