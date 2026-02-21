{ lib, config, ... }:
{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
    };
    author.name = lib.mkOption {
      type = lib.types.str;
    };
    version = lib.mkOption {
      type = lib.types.str;
    };
    title = lib.mkOption {
      type = lib.types.str;
      default = config.name;
    };

    gestaltIR = lib.mkOption {
      type = lib.types.attrsOf lib.types.raw;
      default = {
        name = config.name;
        title = config.title;
        version = config.version;
        initialState = config.final.initialState;
        stateType = lib.warn "stateType not implemented yet, will probably be removed" config.stateType;
        actions = config.final.actions;
        view = config.final.view;
        author = config.author;
      };
      description = "The intermediate representation of the application.";
    };

    final.actions =
      let
        stateHooks = config.stateHooks;
      in

      lib.mkOption {
        type = lib.types.attrs;
        readOnly = true;
        default =

          builtins.mapAttrs (
            _: action:
            action
            // {
              function =
                { state, params }:
                {
                  state = lib.pipe (action.function { inherit state params; }).state (stateHooks);
                  # b = throw config.stateHooks;
                  effect = (action.function { inherit state params; }).effect;
                };
            }
          ) config.actions;
      };
    final.initialState = lib.mkOption {
      readOnly = true;

      type = lib.types.attrs;

      default = builtins.trace (builtins.toJSON config.initialState) (
        lib.pipe config.initialState config.stateHooks
      );
    };

    final.view = lib.mkOption {
      readOnly = true;
      type = lib.types.raw;
      default =
        state:
        builtins.map (f: f state) config.view
        |>
          builtins.foldl'
            (acc: curr: {
              elements = acc.elements ++ curr.elements;
              actions = acc.actions ++ curr.actions;
            })
            {
              elements = [ ];
              actions = [ ];
            };
    };
  };
}
