{ pkgs, inputs, ... }:
(pkgs.lib.evalModules {
  modules = [
    ./buildApplication.nix
    ./targets/web/module.nix
    ./targets/tui/module.nix
    ./publish.nix
    {
      options.gestaltPlatform.buildApplication = pkgs.lib.mkOption {
        type = pkgs.lib.types.raw;
      };
      options.gestaltPlatform.targets = pkgs.lib.mkOption {
        type = pkgs.lib.types.attrsOf pkgs.lib.types.raw;
        default = { };
      };
      options.gestaltPlatform.publish = pkgs.lib.mkOption {
        type = pkgs.lib.types.raw;
      };
    }
  ];
  specialArgs = {
    inherit (pkgs) lib;
    inherit pkgs;
    inherit inputs;
  };
}).config.gestaltPlatform
