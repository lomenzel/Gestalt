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
        lib.warn "Upstream nix compat mode using recursive nix is very experimental. expect critical errors"
          (
            pkgs.callPackage ./upstreamCompat.nix {
              inherit (inputs)
                nixFork
                nixpkgs
                wechselbalg
                self
                kirigami-target
                ;
              inherit
                inputs
                src
                mainFile
                target
                extraTargets
                pkgs
                ;
              inherit (config.gestaltPlatform) buildApplication;
            }
          )
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
