{ lib, config, ... }:
let
  inherit (config) parseBody;
in
{

  bodyParsers = {
    or =
      rawBody: scopes:
      parseBody {
        _expr = "not";
        value = {
          _expr = "and";
          value = {
            e1 = {
              _expr = "not";
              value = rawBody.value.e1;
            };
            e2 = {
              _expr = "not";
              value = rawBody.value.e2;
            };
          };
        };
      } scopes;

    notEquals =
      rawBody: scopes:
      parseBody {
        _expr = "not";
        value = {
          _expr = "equals";
          value = {
            e1 = rawBody.value.e1;
            e2 = rawBody.value.e2;
          };
        };
      } scopes;
    implies =
      rawBody: scopes:
      parseBody {
        _expr = "or";
        value = {
          e1 = {
            _expr = "not";
            value = rawBody.value.e1;
          };
          e2 = rawBody.value.e2;
        };
      } scopes;

    lambda =
      rawBody: scopes:
      let
        #parsedFunction = function {name = rawBody.value.id; value = rawBody.value; };
      in
      {
        helperFunctions = {
          ${rawBody.value.id} = rawBody.value // {
            outerScopes = scopes;
          };
        };
        body = {
          _expr = "lambdaRef";
          value = {
            name = rawBody.value.id;
          };
        };
      };

    var =
      rawBody: scopes:
      let
        hasVar = lib.findFirst (scope: builtins.hasAttr rawBody.value.name scope) null scopes;
      in
      if hasVar == null then
        throw "Unknown variable reference: ${rawBody.value.name}, scopes: ${builtins.toJSON scopes}"
      else

        {
          helperFunctions = { };
          body =
            {
              _expr = "scopeRef";
              value = {
                name = rawBody.value.name;
              }
              // (
                if builtins.hasAttr "field" rawBody.value then
                  {
                    field = rawBody.value.field;
                  }
                else
                  {
                    field = [];
                  }
              );

            };
        };

    call =
      rawBody: scopes:

      let
        modifiedArgs =
          builtins.foldl'
            (
              acc: curr:
              let
                parsedArg = parseBody curr scopes;

              in
              {
                helperFunctions = acc.helperFunctions // parsedArg.helperFunctions;
                args = acc.args ++ [
                  {
                    _expr = "update";
                    value = {
                      e1 = {
                        _expr = "update";
                        value = {
                          e1 = {
                            _expr = "scope";
                          };
                          e2 = parsedArg.body;
                        };
                      };
                      e2 = {
                        __value = parsedArg.body;
                      };
                    };
                  }
                ];
              }
            )
            {
              helperFunctions = { };
              args = [ ];
            }
            rawBody.value.args;

        parsedBody = parseBody rawBody.value.function scopes;
      in
      {
        helperFunctions = modifiedArgs.helperFunctions // parsedBody.helperFunctions;
        body = rawBody // {
          value = rawBody.value // {
            args = modifiedArgs.args;
            function = parsedBody.body;
          };
        };
      };
  };

}
