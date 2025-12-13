{ pkgs, appData }:
let
  result = pkgs.lib.evalModules {
    modules = [
      (
        { ... }:
        {
          config._module.args = {
            inherit pkgs;
            inherit (appData)
              target
              name
              author
              version
              ;
          };
        }
      )
      ./modules/default.nix
    ]
    ++ appData.modules;
  };

  toRawIR = import ./toRawIR.nix pkgs;

  typeHelpers = import ./types/helpers.nix pkgs;

  spTypes = typeHelpers.splitType result.config.types result.config.stateType;

  actions =
    toRawIR result.config.actions "action" |> normalization.actions spTypes.types spTypes.type;

  normalization = import ./normalize.nix pkgs;

in
appData.target.buildApplication {
  actions = actions.actions;
  initialState = result.config.initialState;
  stateType = spTypes.type;
  types = actions.functions.types;
  functions = actions.functions.functions;
  inherit (appData)
    version
    name
    author
    title
    ;
}
