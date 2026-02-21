{ pkgs, ... }:
(pkgs.lib.evalModules {
  modules = [
    ./toJS.nix
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

}).config.lib