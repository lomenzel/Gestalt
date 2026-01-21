pkgs:
let

  # normalized struture
  /*
    actions: {
      actionName: functionReference:(state) -> { state, [Effect]}
      ...
    }
    functions: {
      functionReference: Function
    }
  */

  typeHelpers = import ./types/helpers.nix pkgs;

  actions =
    types: stateType: raw:
    let
      actions = pkgs.lib.mapAttrs (
        name: action:
        if action.function._expr == "lambda" then
          {
            function = action.function.value.id;
            paramType = functions.${action.function.value.id}.paramType;

          }
        else if action.function._expr == "lambdaRef" then
          action.function.value
        else
          throw "Invalid action type: ${action.tag} for action ${name}"
      ) raw;
      functions =
        pkgs.lib.filterAttrs (_: f: f.function._expr == "lambda") raw
        |> pkgs.lib.attrsToList
        |> builtins.map (e: {
          name = e.value.function.value.id;
          value = {
            returnType = {
              _type = "struct";
              fields = {
                state = stateType;
                effect = {
                  # TODO effect type (param) handling
                  _type = "string";
                };
              };
            };
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
        |> pkgs.lib.listToAttrs
        |> normalizeAllFunctions

      # TODO type system needs design decisions first
      # |> (
      #   allFunctions:

      #   let
      #     fNamesWithParamTypes =
      #       pkgs.lib.filterAttrs (_: f: builtins.hasAttr "paramType" f) allFunctions
      #       |> pkgs.lib.attrsToList
      #       |> builtins.map (e: e.name);
      #   in
      #   builtins.foldl'
      #     (
      #       acc: curr:
      #       typeHelpers.inferType {
      #         inherit (acc) functions types;
      #         functionName = curr;
      #       }

      #     )
      #     {
      #       functions = allFunctions;
      #       inherit types;
      #     }
      #     fNamesWithParamTypes

      # )
      ;

    in

    {
      inherit functions actions;

    };

  normalizeAllFunctions =
    fs:
    builtins.foldl'
      (
        acc: curr:
        let
          normalizedCurr = (function curr);
          recCall = (normalizeAllFunctions normalizedCurr.helperFunctions);
        in

        acc
        // {
          ${curr.name} = builtins.removeAttrs (curr.value // { body = normalizedCurr.body; }) [
            "implementation"
            "id"
          ];
        }
        // recCall

      )
      {

      }
      (pkgs.lib.attrsToList fs);

  # normalized structure
  /*
    {
      state: Sate {
        type: "int" | "string" | <other primitives> | { name : State}
        initialValue: <value>(same type as defined in "type") only for primitives
        public: bool | functionreference(state -> bool) # is hirarchical
      }
      functions: {
        referenceName: unnormalized Function
      }
    }
  */

  /*
    {
      parameters: {
        name: type;
      }
      returns: type;
      body: function body that may only reference other functionReferences from helper functions or self

      helperFunctions: {

        functionReference:  Function
      }
  */
  function =
    rawFunction:
    (
      if rawFunction.value.implementation._expr == "primop" then
        {
          body = rawFunction.value.implementation;
          helperFunctions = { };
        }
      else
        let

          parseVariableSubstitution =
            arguments:
            let
              id =
                if arguments.identifier != null then
                  {
                    ${arguments.identifier} = {
                      _expr = "param";
                    };
                  }
                else
                  { };
              formals =
                builtins.map (e: {
                  name = e.name;
                  value = {
                    _expr = "param";
                    field = [ e.name ];
                  }
                  // (
                    if e.defaultExpr or null != null then
                      {
                        default = e.defaultExpr;
                      }
                    else
                      { }
                  );
                }) arguments.formals or [ ]
                |> pkgs.lib.listToAttrs;
            in
            (id // formals);

          parseResult = parseBody rawFunction.value.implementation.value.body (
            [
              (parseVariableSubstitution rawFunction.value.implementation.value.arguments)
            ]
            ++ (rawFunction.value.outerScopes or [ ])
          );

          parseBody =
            rawBody: scopes:
            (
              if
                builtins.elem (builtins.typeOf rawBody) [
                  "int"
                  "string"
                  "bool"
                  "float"
                  "null"
                  "path"
                ]
              then
                {
                  helperFunctions = { };
                  body = rawBody;
                }
              else if builtins.typeOf rawBody == "list" then

                let
                  recCall = builtins.map (e: parseBody e scopes) rawBody;
                in
                {
                  helperFunctions = builtins.foldl' (acc: curr: acc // curr.helperFunctions) { } recCall;
                  body = builtins.map (e: e.body) recCall;
                }

              else if
                builtins.typeOf rawBody == "set"
                && (
                  !builtins.hasAttr "_expr" rawBody
                  || rawBody._expr == "lambdaRef"
                  || rawBody._expr == "if"
                  || rawBody._expr == "primop"
                  || rawBody._expr == "concatString/addition"
                  || rawBody._expr == "select"
                  || rawBody._expr == "attrName"
                  || rawBody._expr == "update"
                  || rawBody._expr == "concatLists"
                  || rawBody._expr == "not"
                  || rawBody._expr == "equals"
                  || rawBody._expr == "and"
                )
              then

                let
                  parsedFields = pkgs.lib.mapAttrs (
                    name: field:
                    let
                      parsedField = parseBody field scopes;
                    in
                    {
                      helperFunctions = parsedField.helperFunctions;
                      body = parsedField.body;
                    }
                  ) rawBody;
                in
                {
                  body = pkgs.lib.mapAttrs (n: f: f.body) parsedFields;
                  helperFunctions = builtins.foldl' (acc: curr: acc // curr.value.helperFunctions) { } (
                    pkgs.lib.attrsToList parsedFields
                  );
                }

              else if builtins.typeOf rawBody == "set" && rawBody._expr == "or" then
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
                } scopes

              else if builtins.typeOf rawBody == "set" && rawBody._expr == "notEquals" then
                parseBody {
                  _expr = "not";
                  value = {
                    _expr = "equals";
                    value = {
                      e1 = rawBody.value.e1;
                      e2 = rawBody.value.e2;
                    };
                  };
                } scopes
              else if builtins.typeOf rawBody == "set" && rawBody._expr == "implies" then
                parseBody {
                  _expr = "or";
                  value = {
                    e1 = {
                      _expr = "not";
                      value = rawBody.value.e1;
                    };
                    e2 = rawBody.value.e2;
                  };
                }

              else if builtins.typeOf rawBody == "set" && rawBody._expr == "lambda" then

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
                }

              else if builtins.typeOf rawBody == "set" && rawBody._expr == "var" then
                # todo
                if builtins.hasAttr rawBody.value.name (builtins.head scopes) then

                  {
                    helperFunctions = { };
                    body =
                      let
                        value = (builtins.head scopes).${rawBody.value.name};
                      in
                      value
                      // {
                        field = (if builtins.hasAttr "field" value then [ "__value" ] ++ value.field else [ "__value" ]);
                      };
                  }
                else if (pkgs.lib.any (scope: builtins.hasAttr rawBody.value.name scope) scopes) then
                  #throw "variable reference across scopes not yet implemented: ${rawBody.value.name}, scopes: ${builtins.toJSON scopes}"
                  {
                    helperFunctions = { };
                    body =
                      let
                        outerScopeValue =
                          (pkgs.lib.findFirst (builtins.hasAttr rawBody.value.name)
                            (throw "this should never ever happen. there exists a scope with the variable, but findFirst failed")
                            scopes
                          ).${rawBody.value.name};
                      in
                      outerScopeValue
                      // {
                        field = (
                          if builtins.hasAttr "field" outerScopeValue then
                            [ "__env" ] ++ [ rawBody.value.name ] ++ outerScopeValue.field
                          else
                            [ "__env" ] ++ [ rawBody.value.name ]
                        );
                      };
                  }
                else
                  throw "Unknown variable reference: ${rawBody.value.name}, scopes: ${builtins.toJSON scopes}"

              else if builtins.typeOf rawBody == "set" && rawBody._expr == "call" then
                #throw "call looks like : ${builtins.toJSON rawBody} - call not yet implemented in normalization"

                # only rewrite arguments to be a set of {__env, __value} with env is outer __env // params... and value is the actual parameter
                let
                  modifiedArgs = builtins.foldl ( arg:
                    acc: curr:
                    let
                      parsedArg = parseBody curr scopes;

                    in
                     {
                      helperFunctions = acc.helperFunctions // parsedArg.helperFunctions;
                      value = acc.args ++ [
                        {
                          _expr = "set";
                          value = {
                            __env = {
                              _expr = "var";
                              value = {
                                name = "__env";
                              };
                            };
                            __value = parsedArg.body;
                          };
                        }
                      ];
                     }
                  ) {helperFunctions = {}; args = []; } rawBody.value.args;
                in
                {

                }
              else
                builtins.throw (
                  "Unknown/Unsupported body type: ${builtins.typeOf rawBody} with _expr: ${
                    if builtins.hasAttr "_expr" rawBody then rawBody._expr else "none"
                  }"
                )
            );

        in
        {
          inherit (parseResult) body helperFunctions;

          # returns = "Type inference not implemented yet";
          # parameters = "Type inference not implemented yet";
        }
    );
in
{
  inherit actions;
}
