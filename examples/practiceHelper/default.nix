{
  modules = [
    (
      {
        target,
        config,
        lib,
        ...
      }:
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
          };

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
          task = "not_initialized. run init action to start";
          practiceRange = "not_initialized. run init action to start";
        };

        stateType = {
          _type = "struct";
          fields = {
            done = {
              _type = "jsonvalue";
            };
            task = {
              _type = "jsonvalue";
            };
            practiceRange = {
              _type = "jsonvalue";
            };
          };
        };

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
                  task = { };
                  practiceRange = {
                    # start = params.start;
                    # end = params.end;
                    start = 3;
                    end = 5;
                  };
                };
                effect = target.capabilities.effects.invokeAction {
                  actionId = "next";
                  params = { };
                };
              };
            # paramType = {
            #   _type = "struct";
            #   fields = {
            #     start = {
            #       _type = "int";
            #     };
            #     end = {
            #       _type = "int";
            #     };
            #   };
            # };
          };
          handleRandomResult = {
            function =
              {
                state,
                params,
              }:
              {
                state = state // {
                  done = state.done ++ [ params.result ];
                  task = builtins.elemAt (possibleParts {
                    lower = state.practiceRange.start;
                    upper = state.practiceRange.end;
                    done = state.done ++ [ params.result ];
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
              }:
              {
                state = state;
                effect = target.capabilities.effects.random {
                  from = 1;
                  to = builtins.length (possibleParts {
                    lower = state.practiceRange.start;
                    upper = state.practiceRange.end;
                    done = state.done;
                  });
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
      }
    )
  ];
  title = "Practice Helper (Gestalt Example)";
  name = "practice-helper";
  version = "0.0.1";
  author.name = "Leonard Menzel";
}
