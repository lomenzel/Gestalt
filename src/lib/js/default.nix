{ lib, pkgs, config, ... }:
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
        inherit (ir) view;
      };
    in
    pkgs.writeText "gestaltCore.js" ''
      // class definition
      ${builtins.readFile ./core.js}

      export const core = new GestaltCore(${config.lib.toJS constructorParam});
      export const actionParamTypes = ${config.lib.toJS actionParams};
    '';

}
