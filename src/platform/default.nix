{ pkgs, ... }:
(pkgs.lib.evalModules {
  modules = [
    ./buildGestaltApplication.nix
    ./targets/cli/default.nix
    ./targets/web/default.nix
    {
      options.gestaltPlatform.buildGestaltApplication = pkgs.lib.mkOption {
        type = pkgs.lib.types.raw;
      };
      options.gestaltPlatform.targets = pkgs.lib.mkOption {
        type = pkgs.lib.types.attrsOf pkgs.lib.types.raw;
        default = { };
      };
    }
  ];
  specialArgs = {
    inherit (pkgs) lib;
    inherit pkgs;
  };
}).config.gestaltPlatform
