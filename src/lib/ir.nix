{ lib, ... }:
{
  lib.mkGestaltIR =
    { target, modules }:
    (lib.evalModules {
      modules = modules ++ [
        ../modules/default.nix
      ];
      specialArgs = {
        inherit target;
      };
    }).config.gestaltIR;
}
