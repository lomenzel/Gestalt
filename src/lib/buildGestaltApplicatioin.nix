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

  state = toRawIR result.config.state "state" |> normalization.state;
  actions = toRawIR result.config.actions "action" |> normalization.actions;

  normalization = import ./normalize.nix pkgs;

in
appData.target.buildApplication {
  actions = actions.actions;
  state = state.state;
  functions = actions.functions // state.functions;
  inherit (appData)
    version
    name
    author
    title
    ;
}
