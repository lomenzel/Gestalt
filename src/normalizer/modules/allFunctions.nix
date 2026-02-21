{ config, lib, ... }:
{
  normalizeAllFunctions =
    functions:
    builtins.foldl'
      (
        acc: curr:
        let
          normalizedCurr = (config.normalizeFunction curr);
          recCall = (config.normalizeAllFunctions normalizedCurr.helperFunctions);
        in

        acc
        // {
          ${curr.name} = builtins.removeAttrs (curr.value // { body = normalizedCurr.body; } // (if normalizedCurr ? arguments then { inherit (normalizedCurr) arguments; } else {})) [
            "implementation"
            "id"
          ];
        }
        // recCall

      )
      {

      }
      (lib.attrsToList functions);

}
