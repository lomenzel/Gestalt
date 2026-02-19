{ lib, config, ... }:
{
  normalizeActions =
    types: stateType: raw:
    let
      functions =
        lib.filterAttrs (_: f: f.function._expr == "lambda") raw
        |> lib.attrsToList
        |> builtins.map (e: {
          name = e.value.function.value.id;
          value = {
            # TODO Type system
            paramType = {
              _type = "struct";
              fields = {
                state = stateType;
              }
              // (
                if builtins.hasAttr "paramType" (raw.${e.name}) then
                  { params = (raw.${e.name}).paramType; }
                else
                  { }
              );
            };
            implementation = e.value.function.value.implementation;
          };
        })
        |> lib.listToAttrs
        |> config.normalizeAllFunctions;
    in
    {
      inherit functions;
      actions = lib.mapAttrs (
        name: action:
        if action.function._expr == "lambda" then
          {
            function = action.function.value.id;
            paramType = functions.${action.function.value.id}.paramType;
          }
        else
          throw lib.error "Action ${name} does not have a lambda function as its implementation."
      ) raw;
    };
}
