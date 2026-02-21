pkgs:
let
  config =
    (pkgs.lib.evalModules {
      modules = [
        ./modules/default.nix
      ];
    }).config;
in
{
  inherit (config) normalizeActions;
}
