{ lib, config, ... }:
let
  inherit (config) parseVariableSubstitution parseBody;
in
{
  normalizeFunction =
    rawFunction:
    (
      if rawFunction.value.implementation._expr == "primop" then
        {
          body = rawFunction.value.implementation;
          helperFunctions = { };
        }
      else
        let

          parsedResult = parseBody rawFunction.value.implementation.value.body (
            [
              (parseVariableSubstitution rawFunction.value.implementation.value.arguments)
            ]
            ++ (rawFunction.value.outerScopes or [ ])
          );

       in
        {
          inherit (parsedResult) body helperFunctions;
          arguments = rawFunction.value.implementation.value.arguments;
        }
    );
}
