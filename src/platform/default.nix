{ pkgs, inputs, ... }:
(pkgs.lib.evalModules {
  modules = [
    ./buildApplication.nix
    ../targets/test/default.nix
    {
      options.gestaltPlatform.buildApplication = pkgs.lib.mkOption {
        type = pkgs.lib.types.raw;
      };
      options.gestaltPlatform.targets = {
        test = pkgs.lib.mkOption {
          type = pkgs.lib.types.raw;
        };
      };
    }
  ];
  specialArgs = {
    inherit (pkgs) lib;
    inherit pkgs;
    inherit inputs;
  };
}).config.gestaltPlatform
