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
    toRawIR result.config.actions "action" |> normalizeActions spTypes.types spTypes.type;

  inherit (import ./normalizer/default.nix pkgs) normalizeActions;

in
appData.target.buildApplication {
  actions = actions.actions;
  initialState = result.config.initialState;
  stateType = spTypes.type;
  #types = spTypes.types;
  # TODO actions structure has changed
  functions = actions.functions;
  inherit (appData)
    version
    name
    author
    title
    ;
}
