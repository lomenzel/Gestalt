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
          target.module
        ];
        specialArgs = {
          inherit lib;
          inherit target;
        };
      };

      # Build the moduleArgs that the user view function expects, but
      # WITHOUT capturing the whole evalModules result (which would drag
      # in lib's option metadata when reified by wechselbalg).
      #
      # User view modules in practice only use the `state`/`config` arg of
      # their inner `view = { state, config, ... }: …` lambda, not the outer
      # module's `config`, so an empty placeholder suffices here.
      moduleArgs = {
        inherit lib target;
        config = { };
      };

      importIfPath = m: if builtins.isPath m || builtins.isString m then import m else m;
      applyIfFunction = m: if builtins.isFunction m then m moduleArgs else m;
      asModule = m: applyIfFunction (importIfPath m);

      # Collect raw user-side `view` definitions WITHOUT going through
      # `lib.evalModules` (whose wrappers leak the lib closure into the
      # reified IR).
      userViewDefs = builtins.filter (x: x != null) (map (m: (asModule m).view or null) modules);

      # The target's view module declares the option schema. Always include
      # it as the first def so fastEvalModules sees the option declarations.
      targetViewDef =
        (asModule target.module).view or (throw "mkGestaltIR: target.module has no `view` declaration");

      viewDefs = [ targetViewDef ] ++ userViewDefs;

      # Per-state hot path. Uses fastEvalModules so the function body is
      # reify-able (wechselbalg) and orders of magnitude smaller than
      # lib.evalModules.
      view' =
        state:
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
