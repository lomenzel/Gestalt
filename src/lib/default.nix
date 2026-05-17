{ lib, ... }:
let
  fastEvalModules = import ./fastEvalModules.nix;
  viewSchema = import ./viewSchema.nix;
in
{
  inherit fastEvalModules viewSchema;
  standardPageView = import ./standardPageView.nix;

  mkGestaltIR =
    { target, modules, ... }:
    let
      r = lib.evalModules {
        modules = modules ++ [
          ../modules/default.nix
        ] ++ target.modules;
        specialArgs = {
          inherit lib;
          inherit target;
        };
      };

      viewDefs = r.options.view.definitions;

      view' =
        state:
        # fastEvalmodules is used to avoid the need to compile entire nixpkgs lib. its only compile time optimization
        (fastEvalModules {
          modules = viewDefs;
          specialArgs = { inherit state; };
        }).config.componentTree;
    in
    {
      inherit (r.config) meta;
      initialState = r.config.init.state;
      initialEffect = r.config.init.effect;
      view = view';
      exampleView = view' r.config.init.state;
    };
}