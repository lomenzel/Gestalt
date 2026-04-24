{ lib, ... }:
{
  mkGestaltIR =
    { target, modules, ... }:
    let
      r = lib.evalModules {
        modules = modules ++ [
          ../modules/default.nix
          target.module
        ];
        specialArgs = {
          inherit lib;
          inherit target;
        };
      };

      view' = state: (lib.evalModules {
        modules = r.options.view.definitions;
        specialArgs = {
          inherit state;
        };
      }).config.componentTree;
    in
    {
      inherit (r.config) meta;
      initialState = r.config.init.state;
      initialEffect = r.config.init.effect;
      view = view';
      exampleView =  view' r.config.init.state;

    };
}
