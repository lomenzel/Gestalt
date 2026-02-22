{ pkgs, ... }:
(pkgs.lib.evalModules {
  modules = [
    ./js/default.nix
    ./findNew.nix
    ./eval.nix
    ./ir.nix
    {
      options.lib = pkgs.lib.mkOption {
        type = pkgs.lib.types.attrsOf pkgs.lib.types.raw;
        default = {};
      };
    }
  ];
  specialArgs = {
    inherit (pkgs) lib;
    inherit pkgs;
  };

}).config.lib