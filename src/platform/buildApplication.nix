{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  gestaltPlatform.buildApplication =
    {
      modules ? throw "You must provide a list of modules to build an application.",
      target ? config.gestaltPlatform.targets.kirigami,
      extraTargets ? config.gestaltPlatform.targets,
      useUpstreamNix ? (!builtins.hasAttr "reify" builtins) || !builtins.hasAttr "sameFunction" builtins,
      src ? null,
      mainFile ? "app.nix",
    }:
    if useUpstreamNix then
      if src == null then
        throw "You must provide a source directory instead of modules when using upstream nix compatibility mode."
      else
        throw "U have to use the nix fork to evaluate."
    else
      let
        modules' = if src != null then [ ("${src}/${mainFile}") ] else modules;
        ir = lib.mkGestaltIR {
          inherit target;
          modules = modules';

        };

        app = target.buildApplication ir;
      in
      (app.overrideAttrs (old: {
        passthru = (old.passthru or { }) // {
          extraTargets =
            old.passthru.extraTargets or { }
            // (lib.mapAttrs (
              name: target:
              target.buildApplication (
                lib.mkGestaltIR {
                  inherit target;
                  modules = modules';
                }
              )
            ) extraTargets);
          publish = config.gestaltPlatform.publish modules';
        };
      }));
}
