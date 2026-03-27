{ lib, target, ... }:

let
  inherit (import ./lib.nix { inherit lib; }) possibleParts;

  factorial = n: if n == 0 then 1 else n * factorial (n - 1);

  chose = n: r: (factorial n) / ((factorial r) * (factorial (n - r)));

  numberOfPracticeParts = { start, end }: (chose (end - start + 1) 2) + (end - start + 1);

  percentageDone =
    done: practiceRange: ((builtins.length done - 1) * 1.0) / numberOfPracticeParts practiceRange;
in
{

  imports = [ ./tests.nix ];

  initialState = {
    done = "not_initialized. run init action to start";
    task = "No Practice Session initialized. Please start a new session.";
    practiceRange = "not_initialized. run init action to start";
  };

  showcaseState = {
    # only used for percentage real values dont matter currently
    done = [
      2
      3
      4
      23
      34
      24
    ];
    practiceRange = {
      start = 1;
      end = 5;
    };
    task = {
      start = 2;
      end = 4;
    };
  };

  view = [
    (state: {
      elements = [
        {
          content = state.message;
          annotations = [ target.capabilities.annotations.Text.important ];
        }
      ]
      ++ (
        if builtins.typeOf state.task != "string" then
          [
            {
              content = "Current Practice Range: from ${builtins.toString state.practiceRange.start} to ${builtins.toString state.practiceRange.end}";
              annotations = [ target.capabilities.annotations.Text.muted ];
            }
            {
              content = percentageDone state.done state.practiceRange;
              annotations = [ target.capabilities.annotations.Progress.bar ];
            }
          ]
        else
          [ ]
      );
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
              annotations = [ target.capabilities.annotations.Button.primary ];
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
          state = {
            done = [ ];
            task = "initializing";
            practiceRange = {
              start = params.start;
              end = params.end;
            };
          };
          effect = target.capabilities.Effects.Actions.invoke "next" { };
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
          ...
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
        };
      paramType = {
        _type = "struct";
        fields = {
          result = {
            _type = "int";
          };
        };
      };
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
          }
        else
          {
            state = state;
            effect = target.capabilities.Effects.Random.int 0 (
              (builtins.length (possibleParts {
                lower = state.practiceRange.start;
                upper = state.practiceRange.end;
                done = state.done;
              }))
              - 1
            ) "handleRandomResult";
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
  version = "0.0.2";
  author.name = "Leonard Menzel";
}
