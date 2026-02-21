{ lib, config, ... }:
let
  foldl'' =
    op: nul: list:
    builtins.foldl' op nul list;
  pipe =
    (
      op: nul: list:
      builtins.foldl' op nul list
    )
      (x: f: f x);
in
{
    imports = [
      ./ir.nix
    ];

  options = {
    stateType = lib.mkOption {
      type = lib.types.attrs;
      default = {
        _type = "struct";
        fields = { };
      };
      description = "The type of state representation to use.";
    };
    initialState = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "The initial state of the application.";
    };
    actions = lib.mkOption {
      type = lib.types.attrs;
    };
    types = lib.mkOption {
      type = lib.types.attrs;
      default = { };
    };
    stateHooks = lib.mkOption {
      type = lib.types.listOf lib.types.raw;
      default = [ ];
    };
    view = lib.mkOption {
      type = lib.types.listOf lib.types.raw;
      default = [ ];
      description = ''
        function taking state and returning 
        {
          elements: [{
            content = string
            annotations = [string]
          }...],
          actions: [{
            content = string
            actionId = string
            annotations = [string]
          }...]
        }

      '';
    };

  };
}
