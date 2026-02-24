{ lib, target, ... }:

let
  possibleParts =
    {
      lower,
      upper,
      done,
    }:
    allParts { inherit lower upper; }
    |> builtins.filter (part: !builtins.elem part done)
    |> builtins.filter (part: allSubPartsDone { inherit part done; });

  allParts =
    { lower, upper }:
    cartesianProduct {
      start = range {
        lower = lower;
        upper = upper;
      };
      end = range {
        lower = lower;
        upper = upper;
      };
    }
    |> builtins.filter (part: part.start <= part.end);

  cartesianProduct =
    { start, end }:
    builtins.concatMap (
      s:
      builtins.map (e: {
        start = s;
        end = e;
      }) end
    ) start;

  range = { lower, upper }: builtins.genList (n: lower + n) (upper - lower + 1);

  allSubPartsDone =
    { part, done }:
    builtins.all (sp: builtins.elem sp done) (
      allParts {
        lower = part.start;
        upper = part.end;
      }
      |> lib.subtractLists [ part ]
    );

in

{
  initialState = {
    done = "not_initialized. run init action to start";
    task = "No Practice Session initialized. Please start a new session.";
    practiceRange = "not_initialized. run init action to start";
  };

  view = [
    (state: {
      elements = [
        {
          content = state.message;
          annotations = [ target.capabilities.annotations.ui.important ];
        }
      ];
      actions = [
        {
          content = "Start new Practice Session";
          annotations = [ ];
          actionId = "init";
        }
      ]
      ++ (
        if builtins.typeOf state.task != "string" then
          [
            {
              content = "Next task!";
              annotations = [ target.capabilities.annotations.actions.primary ];
              actionId = "next";
            }
          ]
        else
          [ ]
      );
    })
  ];

  stateHooks = [
    (

      state:
      state
      // {
        message =
          if builtins.typeOf state.task == "string" then
            state.task
          else
            "Practice Part: ${
              if state.task.start == state.task.end then
                builtins.toString state.task.start
              else
                "from ${builtins.toString state.task.start} to ${builtins.toString state.task.end}"
            }";
      }

    )
  ];

  actions = {
    init = {
      function =
        {
          state,
          params,
        }:
        {
          # todo
          state = {
            done = [ ];
            task = "initializing";
            practiceRange = {
              start = params.start;
              end = params.end;
            };
          };
          effect = target.capabilities.effects.invokeAction {
            actionId = "next";
            params = { };
          };
        };
      paramType = {
        _type = "struct";
        fields = {
          start = {
            _type = "int";
          };
          end = {
            _type = "int";
          };
        };
      };
    };
    handleRandomResult = {
      function =
        {
          state,
          params,
        }:
        {
          state = state // {
            done = state.done ++ [
              (builtins.elemAt (possibleParts {
                lower = state.practiceRange.start;
                upper = state.practiceRange.end;
                done = state.done;
              }) params.result)
            ];
            task = builtins.elemAt (possibleParts {
              lower = state.practiceRange.start;
              upper = state.practiceRange.end;
              done = state.done;
            }) params.result;
          };
          effect = target.capabilities.effects.noop;
        };
      paramType =
        (target.capabilities.effects.random {
          from = 1;
          to = 2;
          callbackActionId = "handleRandomResult";
        }).callBackParamType;
    };
    next = {
      function =
        {
          state,
          ...
        }:
        if
          (builtins.length (possibleParts {
            lower = state.practiceRange.start;
            upper = state.practiceRange.end;
            done = state.done;
          })) == 0
        then
          {
            state = state // {
              task = "All done! Please start a new Session.";
            };
            effect = target.capabilities.effects.noop;
          }
        else
          {
            state = state;
            effect = target.capabilities.effects.random {
              from = 0;
              to =
                (builtins.length (possibleParts {
                  lower = state.practiceRange.start;
                  upper = state.practiceRange.end;
                  done = state.done;
                }))
                - 1;
              callbackActionId = "handleRandomResult";
            };
          };
      paramType = {
        _type = "struct";
        fields = {
        };
      };
    };

  };

  title = "Practice Helper (Gestalt Example)";
  name = "practice-helper";
  version = "0.0.1";
  author.name = "Leonard Menzel";
}
