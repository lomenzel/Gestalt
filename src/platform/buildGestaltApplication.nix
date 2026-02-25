{ config, lib, pkgs, inputs, ... }:
{
  gestaltPlatform.buildGestaltApplication =
    {
      modules ? throw "You must provide a list of modules to build an application.",
      target ? config.gestaltPlatform.targets.tui,
      extraTargets ? config.gestaltPlatform.targets,
      useUpstreamNix ? (! builtins.hasAttr "reify" builtins) || ! builtins.hasAttr "sameFunction" builtins,
      src ? null,
      mainFile ? "default.nix",
    }:
    if useUpstreamNix then
      if src == null then throw "You must provide a source directory instead of modules when using upstream nix compatibility mode." else
      lib.warn "You are using upstream nix compatibility mode. Expect some limitations and differences in behavior." (pkgs.callPackage ./upstreamCompat.nix {
        nixFork = inputs.nixFork;
        nixpkgs = inputs.nixpkgs;
        inherit src mainFile config target extraTargets;
      })
    else
    let
      ir =  if src != null then 
        lib.mkGestaltIR {
          inherit target;
          modules = [ ("${src}/${mainFile}") ];
        }
        else lib.mkGestaltIR {
          inherit target modules;
        };

      app = target.buildApplication ir;
    in
    app.overrideAttrs (old: {
      passthru = (old.passthru or {}) // {
        extraTargets = old.passthru.extraTargets or {} // (lib.mapAttrs (name: target: target.buildApplication (lib.mkGestaltIR { inherit target modules; })) extraTargets);
      };
    });
}
