{ lib, config, ... }:
{

  imports = [
    ./actions.nix
    ./allFunctions.nix
    ./function.nix
    ./helperFunctions.nix
    ./bodyParser/default.nix
  ];

  options = {
    normalizeActions = lib.mkOption {
      type = lib.types.anything;
      description = "Function that takes in 
      types, stateType and raw
      and returns normalized actions.
      ";
    };
    normalizeAllFunctions = lib.mkOption {
      type = lib.types.anything;
      description = "Function that normalizes all functions.";
    };
    normalizeFunction = lib.mkOption {
      type = lib.types.anything;
      description = "Function that normalizes a single function.";
    };
  };
}
