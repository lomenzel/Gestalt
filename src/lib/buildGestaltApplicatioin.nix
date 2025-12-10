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

  initialStatestate = result.config.initialState;
  stateType = result.config.stateType;
  normalizedActions = toRawIR result.config.actions "action" |> normalization.actions;
  functions = normalizedActions.functions;

  typedFunctions = import ./returnTypes.nix pkgs 
    functions stateType actions
    ;

  normalization = import ./normalize.nix pkgs;

in
appData.target.buildApplication {
  actions = normalizedActions.actions;
  state = initialState;
  functions = actions.functions // state.functions;
  types = 
  inherit (appData)
    version
    name
    author
    title
    ;
}
