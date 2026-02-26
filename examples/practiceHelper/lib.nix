{ lib }:
rec {
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
}
