{ lib, ... }:
{
  mkGestaltIR =
    { target, modules, ... }:
    let
      r = lib.evalModules {
        modules = modules ++ [
          ../modules/default.nix
        ];
        specialArgs = {
          inherit lib;
          inherit target;
        };
      };

    in
    r.config;
}
