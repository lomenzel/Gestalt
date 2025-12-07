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
  actions =
    raw:

    {
      actions = pkgs.lib.mapAttrs (
        name: action:
        if action._expr == "lambda" then
          action.value.id
        else if action._expr == "lambdaRef" then
          action.value
        else
          throw "Invalid action type: ${action.tag} for action ${name}"

      ) raw;
      functions =
        pkgs.lib.filterAttrs (_: f: f._expr == "lambda") raw
        |> pkgs.lib.attrsToList
        |> builtins.map (e: {
          name = e.value.value.id;
          value = e.value.value;
        })
        |> pkgs.lib.listToAttrs
        |> normalizeAllFunctions;

    };

  normalizeAllFunctions =
    fs:
    builtins.foldl' (
      acc: curr:
      let
        normalizedCurr = (function curr);
      in
      (
        acc
        // {
          ${curr.name} = { inherit (normalizedCurr) body; };
        }
        // (normalizeAllFunctions normalizedCurr.helperFunctions)
      )
    ) { } (pkgs.lib.attrsToList fs);

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
  state =
    rawState:
    let
      s = state' rawState;
    in
    {
      state = s.state;
      functions = normalizeAllFunctions s.helperFunctions;
    };

  state' =
    rawState:

    if
      builtins.elem (builtins.typeOf rawState) [
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
        state = rawState;
      }
    else if builtins.typeOf rawState == "list" then

      let
        recCall = builtins.map (e: state e) rawState;
      in
      {
        helperFunctions = builtins.foldl' (acc: curr: acc // curr.helperFunctions) { } recCall;
        state = builtins.map (e: e.state) recCall;
      }

    else if
      builtins.typeOf rawState == "set"
      && (
        !builtins.hasAttr "_expr" rawState
        || rawState._expr == "lambdaRef"
        || rawState._expr == "call"
        || rawState._expr == "if"
        || rawState._expr == "primop"
        || rawState._expr == "concatString/addition"
        || rawState._expr == "select"
        || rawState._expr == "attrName"
        || rawState._expr == "update"
        || rawState._expr == "concatLists"
        || rawState._expr == "not"
        || rawState._expr == "equals"
        || rawState._expr == "and"
      )
    then

      let
        parsedFields = pkgs.lib.mapAttrs (
          name: field:
          let
            parsedField = state' field;
          in
          {
            helperFunctions = parsedField.helperFunctions;
            state = parsedField.state;
          }
        ) rawState;
      in
      {
        state = pkgs.lib.mapAttrs (n: f: f.state) parsedFields;
        helperFunctions = builtins.foldl' (acc: curr: acc // curr.value.helperFunctions) { } (
          pkgs.lib.attrsToList parsedFields
        );
      }

    else if builtins.typeOf rawState == "set" && rawState._expr == "or" then
      state' {
        _expr = "not";
        value = {
          _expr = "and";
          value = {
            e1 = {
              _expr = "not";
              value = rawState.value.e1;
            };
            e2 = {
              _expr = "not";
              value = rawState.value.e2;
            };
          };
        };
      }

    else if builtins.typeOf rawState == "set" && rawState._expr == "notEquals" then
      state' {
        _expr = "not";
        value = {
          _expr = "equals";
          value = {
            e1 = rawState.value.e1;
            e2 = rawState.value.e2;
          };
        };
      }
    else if builtins.typeOf rawState == "set" && rawState._expr == "implies" then
      state' {
        _expr = "or";
        value = {
          e1 = {
            _expr = "not";
            value = rawState.value.e1;
          };
          e2 = rawState.value.e2;
        };
      }

    else if builtins.typeOf rawState == "set" && rawState._expr == "lambda" then

      {
        helperFunctions = {
          ${rawState.value.id} = rawState.value;
        };
        state = {
          _expr = "lambdaRef";
          value = {
            name = rawState.value.id;
          };
        };
      }
    else
      throw (
        "Unknown/Unsupported state type: ${builtins.typeOf rawState} with _expr: ${
          if builtins.hasAttr "_expr" rawState then rawState._expr else "none"
        }"
      );

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
            parseVariableSubstitution rawFunction.value.implementation.value.arguments
          );

          parseBody =
            rawBody: varSubstitution:
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
                  recCall = builtins.map (e: parseBody e varSubstitution) rawBody;
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
                  || rawBody._expr == "call"
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
                      parsedField = parseBody field varSubstitution;
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
                } varSubstitution

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
                } varSubstitution
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
                    ${rawBody.value.id} = rawBody.value;
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
                if builtins.hasAttr rawBody.value.name varSubstitution then
                  {
                    helperFunctions = { };
                    body = varSubstitution.${rawBody.value.name};
                  }
                # parseBody (varSubstitution.${rawBody.value.name}) varSubstitution
                else
                  throw "Unknown variable reference: ${rawBody.value.name}"

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
  inherit actions state;
}
