{
  lib,
  config,
  target,
  ...
}:
{
  options = {
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

    gestaltIR = lib.mkOption {
      readOnly = true;
      type = lib.types.attrsOf lib.types.raw;
      default =

        {
          name = config.name;
          title = config.title;
          version = config.version;
          initialState = config.final.initialState;
          initialEffect = config.initialEffect;
          actions = config.final.actions;
          view = config.final.view;
          author = config.author;
          showcaseState = lib.pipe config.showcaseState config.stateHooks;
          unitTests =
            let
              tests = config.tests;
              final = config.final;
              initialEffect = config.initialEffect;
            in
            (builtins.map (test: {
              inherit (test) description func params;
              pass = test.expected.final;
            }) tests.unit)
            ++ builtins.map (
              test:
              let
                runStep =
                  acc: curr:

                  builtins.foldl' runStep
                    {
                      state =
                        (final.actions.${curr.actionId}.function ({
                          inherit (acc) state;
                          inherit (curr) params;
                        })).state;
                      emittedEffects = acc.emittedEffects ++ [
                        (final.actions.${curr.actionId}.function ({
                          inherit (acc) state;
                          inherit (curr) params;
                        })).effect
                      ];
                      states = acc.states ++ [
                        (final.actions.${curr.actionId}.function ({
                          inherit (acc) state;
                          inherit (curr) params;
                        })).state
                      ];
                    }
                    (
                      test.final.effectMocks.${
                        (final.actions.${curr.actionId}.function ({
                          inherit (acc) state;
                          inherit (curr) params;
                        })).effect.id
                      }
                        {
                          effect =
                            (final.actions.${curr.actionId}.function ({
                              inherit (acc) state;
                              inherit (curr) params;
                            })).effect;
                          emittedEffects = acc.emittedEffects;
                          state = acc.state;
                          states = acc.states;
                        }
                    );
              in
              {
                inherit (test) description pass;
                func =
                  initialState:
                  builtins.foldl' (runStep)
                    {
                      state = initialState;
                      emittedEffects = [ ];
                      states = [ initialState ];
                    }
                    (
                      test.steps
                      ++ (test.final.effectMocks.${initialEffect.id} {
                        effect = initialEffect;
                        emittedEffects = [ ];
                        state = initialState;
                        states = [ initialState ];
                      })
                    )
                  |> (
                    res:
                    res
                    // {
                      views = builtins.map (state: final.view state) res.states;
                    }
                  );
                params = test.initialState;
              }
            ) tests.e2e;
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
            let
              af_ = if builtins.typeOf action == "lambda" then action else action.function;
              af =
                { state, params }@p:
                {
                  inherit state;
                  effect = target.capabilities.Effects.Noop;
                }
                // (af_ p);
            in
            (if builtins.typeOf action == "lambda" then { } else action)
            // {
              function =
                { state, params }:
                {
                  state = lib.pipe (af { inherit state params; }).state (stateHooks);
                  # b = throw config.stateHooks;
                  effect = (af { inherit state params; }).effect;
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
