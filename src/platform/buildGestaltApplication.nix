{ config, lib, ... }:
{
  gestaltPlatform.buildGestaltApplication =
    {
      modules,
      target ? config.gestaltPlatform.targets.cli,
      extraTargets ? config.gestaltPlatform.targets,
    }:
    let
      app = target.buildApplication (lib.mkGestaltIR { inherit target modules; });
    in
    app.overrideAttrs (old: {
      passthru = old.passthru // {
        extraTargets = old.passthru.extraTargets or {} // (lib.mapAttrs (name: target: target.buildApplication (lib.mkGestaltIR { inherit target modules; })) extraTargets);
      };
    });
}
