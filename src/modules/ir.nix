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
      readOnly = true;
      type = lib.types.attrsOf lib.types.raw;
      default = {
        name = config.name;
        title = config.title;
        version = config.version;
        initialState = config.final.initialState;
        actions = config.final.actions;
        view = config.final.view;
        author = config.author;
        unitTests =
          let
            tests = config.tests;
            final = config.final;
          in
          (builtins.map (test: {
            inherit (test) description func params;
            pass = test.expected.final;
          }) tests.unit)
          ++ builtins.map (test: {
            inherit (test) description pass;
            func =
              initialState:
              builtins.foldl'
                (acc: curr: {
                  # i realy need to support let in, this look horrific
                  state =
                    (final.actions.${curr.actionId}.function (
                      {
                        state = acc.state;
                        params = curr.params;
                      }
                    )).state;
                  emittedEffects = acc.emittedEffects ++ [
                    (final.actions.${curr.actionId}.function (
                      {
                        state = acc.state;
                        params = curr.params;
                      }
                    )).effect
                  ];
                  states = acc.states ++ [
                    (final.actions.${curr.actionId}.function (
                      {
                        state = acc.state;
                        params = curr.params;
                      }
                    )).state
                  ];
                })
                {
                  state = initialState;
                  emittedEffects = [ ];
                  states = [ initialState ];
                }
                test.steps
                
                |> (res: res // {
                  views = builtins.map (state: final.view state) res.states;
                })
                ;
            params = test.initialState;
          }) tests.e2e;
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

      default = lib.pipe config.initialState config.stateHooks;
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
