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
    tests.unit = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule (
          { config, ... }:
          {
            options = {
              func = lib.mkOption {
                type = lib.types.raw;
              };
              description = lib.mkOption {
                type = lib.types.str;
                default = "Unnamed unit test";
              };
              expected.toBe = lib.mkOption {
                type = lib.types.raw;
                default = null;
              };
              expected.toPass = lib.mkOption {
                type = lib.types.raw;
                default = null;
              };
              params = lib.mkOption {
                type = lib.types.raw;
                default = [ ];
              };
              expected.final = lib.mkOption {
                type = lib.types.raw;
                readOnly = true;
                default =
                  if (config.expected.toBe == null) == (config.expected.toPass == null) then
                    throw "You must specify either expected.toBe or expected.toPass, but not both."
                  else if config.expected.toBe != null then
                    (x: x == config.expected.toBe)
                  else
                    config.expected.toPass;
              };
            };
          }
        )

      );
      default = [ ];
    };
    tests.e2e = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule (
          local:
          {
            options = {
              description = lib.mkOption {
                type = lib.types.str;
                default = "unnamed end-to-end test";
              };
              steps = lib.mkOption {
                type = lib.types.listOf (
                  lib.types.submodule (
                    { config, ... }:
                    {
                      options = {
                        actionId = lib.mkOption {
                          type = lib.types.str;
                        };
                        params = lib.mkOption {
                          type = lib.types.raw;
                          default = null;
                        };
                        hasParam = lib.mkOption {
                          type = lib.types.bool;
                          default = config.params != null;
                        };
                      };
                    }
                  )
                );
              };
              pass = lib.mkOption {
                type = lib.types.raw;
              };
              initialState = lib.mkOption {
                type = lib.types.raw;
                default = config.final.initialState;
              };
              effectMocks = lib.mkOption {
                type = lib.types.attrsOf lib.types.raw;
                default = { };
              };
              final.effectMocks = lib.mkOption {
                type = lib.types.attrsOf lib.types.raw;
                readOnly = true;
                default = {
                  noop = _: [ ];
                  log = _: [ ];
                  invokeAction =
                    { effect, ... }:
                    [
                      {
                        inherit (effect.params) params actionId;
                      }
                    ];
                }
                // local.config.effectMocks;
              };
            };
          }
        )
      );
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
