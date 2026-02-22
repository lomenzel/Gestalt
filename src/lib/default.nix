{ pkgs, ... }:
let
  inherit (pkgs) lib;
in
(pkgs.lib.evalModules {
  modules = [
    ./js/default.nix
    ./cpp/default.nix
    ./findNew.nix
    ./eval.nix
    ./ir.nix
    {
      options.lib = {
        toCpp = lib.mkOption {
          type = lib.types.raw;
        };
        toJS = lib.mkOption {
          type = lib.types.raw;
        };
        evaluateAST = lib.mkOption {
          type = lib.types.raw;
        };
        findNewAttrName = lib.mkOption {
          type = lib.types.raw;
        };
        findNewFunctionName = lib.mkOption {
          type = lib.types.raw;
        };
        gestaltCore = lib.mkOption {
          type = lib.types.attrsOf lib.types.raw;
        };
        mkGestaltIR = lib.mkOption {
          type = lib.types.raw;
        };
      };
    }
  ];
  specialArgs = {
    inherit (pkgs) lib;
    inherit pkgs;
  };

}).config.lib
