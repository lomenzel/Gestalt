{ pkgs, inputs, ... }:
(pkgs.lib.evalModules {
  modules = [
    ./buildApplication.nix
    "${inputs.kirigami-target}/default.nix"
    "${inputs.web-target}/default.nix"
    {
      options.gestaltPlatform.buildApplication = pkgs.lib.mkOption {
        type = pkgs.lib.types.raw;
      };
      options.gestaltPlatform.targets = {
        kirigami = pkgs.lib.mkOption {
          type = pkgs.lib.types.raw;
        };
        web = pkgs.lib.mkOption {
          type = pkgs.lib.types.raw;
        };
      };
      

    }
  ];
  specialArgs = {
    inherit (pkgs) lib;
    inherit pkgs;
    inherit inputs;
    defaultCapabilities = import ./defaultCapabilities.nix;
    standardPageView = import ../lib/standardPageView.nix;
  };
}).config.gestaltPlatform
