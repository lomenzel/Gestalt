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

  options = {
    meta = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "untitled-application";
      };
      author.name = lib.mkOption {
        type = lib.types.str;
        default = "Anonymous Author";
      };
      version = lib.mkOption {
        type = lib.types.str;
        default = "0";
      };
      title = lib.mkOption {
        type = lib.types.str;
        default = config.name;
      };
    };
    init.state = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "The initial state of the application.";
    };
    showcaseState = lib.mkOption {
      type = lib.types.attrs;
      default = config.init.state;
      description = "A showcase state of the application, used for marketing screenshots :)";
    };
    init.effect = lib.mkOption {
      type = lib.types.raw;
      default = target.capabilities.Effects.Noop;
      description = "effect that should be run at application startup";
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

    view = lib.mkOption {
      type = lib.types.submoduleWith {
        modules = [ ];
        specialArgs = {
          state = config.init.state;
        };
      };
      default = { };
    };

  };
}
