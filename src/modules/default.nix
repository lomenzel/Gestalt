{
  lib,
  config,
  target,
  ...
}:
let
  # random implementation stolen from glibc
  m = 2147483648;
  a = 1103515245;
  c = 12345;

  nextRandom = seed: lib.mod (a * seed + c) m;

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
    showcaseState = lib.mkOption {
      type = lib.types.attrs;
      default = config.final.initialState;
      description = "A showcase state of the application, used for marketing screenshots :)";
    };
    initialEffect = lib.mkOption {
      type = lib.types.raw;
      default = target.capabilities.Effects.Noop;
      description = "effect that should be run at application startup";
    };
    actions = lib.mkOption {
      type = lib.types.attrs;
      default = { };
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
                    (
                      x:
                      if (x != config.expected.toBe) then
                        builtins.trace "expected: ${builtins.toJSON config.expected.toBe}; got: ${builtins.toJSON x}" false
                      else
                        (x == config.expected.toBe)
                    )
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
        lib.types.submodule (local: {
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
                Noop = _: [ ];
                Log = _: [ ];
                "store.get" = _: [ ];
                "store.set" = _: [ ];
                invokeActions = { effect, ... }: effect.params.actions;
                "Random.int" =
                  { effect, emittedEffects, ... }:
                  [
                    {
                      actionId = effect.params.callbackActionId;
                      params = {
                        result =
                          effect.params.from
                          + (lib.mod (nextRandom (builtins.length emittedEffects)) (
                            effect.params.to - effect.params.from + 1
                          ));
                      };
                    }
                  ];
                httpRequest = _: [ ];
              }
              // local.config.effectMocks;
            };
          };
        })
      );
      default = [ ];
    };
    view = lib.mkOption {
      type = lib.types.listOf lib.types.raw;
      default = [
        (state: {
          elements = [
            {
              content = "state: ${builtins.toJSON state}";
            }
          ];
          actions =
            builtins.attrNames config.actions
            |> builtins.map (actionId: {
              content = actionId;
              actionId = actionId;
            });
        })
      ];
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
