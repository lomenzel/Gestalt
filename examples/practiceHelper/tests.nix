{ lib, ... }:
let
  inherit (import ./lib.nix { inherit lib; })
    possibleParts
    allParts
    cartesianProduct
    range
    allSubPartsDone
    ;
in
{
  tests.unit = [
    {
      func = possibleParts;
      description = "with nothing done, only one length parts should be possible";
      params = {
        lower = 1;
        upper = 3;
        done = [ ];
      };
      expected.toBe = [
        {
          start = 1;
          end = 1;
        }
        {
          start = 2;
          end = 2;
        }
        {
          start = 3;
          end = 3;
        }
      ];
    }
    {
      func = range;
      description = "range";
      params = {
        lower = 2;
        upper = 9;
      };
      expected.toBe = [
        2
        3
        4
        5
        6
        7
        8
        9
      ];
    }
    {
      func = allSubPartsDone;
      description = "a part with an undone subpart should not be considered done";
      params = {
        part = {
          start = 1;
          end = 3;
        };
        done = [
          {
            start = 1;
            end = 1;
          }
          {
            start = 2;
            end = 2;
          }
          {
            start = 3;
            end = 3;
          }
          {
            start = 1;
            end = 2;
          }
          # missing { start = 2; end = 3;}
        ];
      };
      expected.toBe = false;
    }
    {
      func = allSubPartsDone;
      description = "a part with all subparts done should be considered done";
      params = {
        part = {
          start = 1;
          end = 3;
        };
        done = [
          {
            start = 1;
            end = 1;
          }
          {
            start = 2;
            end = 2;
          }
          {
            start = 3;
            end = 3;
          }
          {
            start = 1;
            end = 2;
          }
          {
            start = 2;
            end = 3;
          }
        ];
      };
      expected.toBe = true;
    }
  ];

  tests.e2e = [
    {
      description = "initializing practice session";
      effectMocks = {
        random =
          { effect, ... }:
          [
            {
              actionId = effect.params.callbackActionId;
              params = {
                result = effect.params.from;
              };
            }
          ];
      };
      steps = [
        {
          actionId = "init";
          params = {
            start = 1;
            end = 3;
          };
        }
      ];
      pass =
        { state, ... }:
        builtins.elem state.task (builtins.genList (i: {
          start = i + 1;
          end = i + 1;
        }) 3);
    }
  ];
}
