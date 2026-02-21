pkgs:
let

  eval =
    { _expr, value }:
    if _expr == "literal" || _expr == "attrName" then
      {
        success = true;
        inherit value;
      }
    else if _expr == "var" then
      {
        success = builtins.hasAttr "closureEnvValue" value;
        value = if builtins.hasAttr "closureEnvValue" value then value.closureEnvValue else null;
      }
    else if _expr == "concatString/addition" then
      let
        operandsEval = builtins.map (o: eval o) value;
        success = builtins.all (o: o.success) operandsEval;
      in
      {
        inherit success;
        value =
          if success then
            builtins.foldl' (acc: curr: acc + curr.value) (builtins.head operandsEval).value (
              builtins.tail operandsEval
            )
          else
            null;
      }
    else if _expr == "list" then
      let
        elementsEval = builtins.map (e: eval e) value;
        success = builtins.all (e: e.success) elementsEval;
      in
      {
        inherit success;
        value = if success then builtins.map (e: e.value) elementsEval else null;
      }
    else if _expr == "lambda" then
      {
        success = false;
        value = null;
      }
    else if _expr == "attrSet" then
      let
        attrsEval = pkgs.lib.mapAttrsToList (name: attr: {
          inherit name;
          value = eval attr;
        }) value.attrs;
        success = builtins.all (a: a.value.success) attrsEval;
      in
      if value.dynamicAttrs != [ ] then
        throw "evaluating reified attrSets with dynamic attributes is not supported yet."
      else if value.recursive then
        throw "evaluating reified recursive attrSets is not supported yet."
      else
        {
          inherit success;
          value =
            if success then
              pkgs.lib.listToAttrs (
                builtins.map (a: {
                  inherit (a) name;
                  inherit (a.value) value;
                }) attrsEval
              )
            else
              null;
        }
    else if _expr == "select" then
      let
        pathEval = builtins.map (p: eval p) value.path;
        exprEval = eval value.expression;
        defaultEval = eval value.default;

        success =
          builtins.all (p: p.success) pathEval
          && exprEval.success
          && ((builtins.hasAttr "default" value) -> defaultEval.success); # TODO  does -> short circuit here?
      in
      {
        inherit success;
        value =
          if success then
            (builtins.foldl'
              (
                acc: curr:
                if !acc.continue then
                  acc
                else if (builtins.hasAttr curr.value acc.value) || (!builtins.hasAttr "default" value) then
                  {
                    continue = true;
                    value = acc.value.${curr.value};
                  }
                else
                  {
                    continue = false;
                    value = defaultEval.value;
                  }
              )
              {
                continue = true;
                value = exprEval.value;
              }
              (pathEval)
            ).value
          else
            null;
      }
    else if _expr == "if" then
      let
        condEval = eval value.condition;
        thenEval = eval value.${"then"};
        elseEval = eval value.${"else"};

        success =
          condEval.success && (condEval.value -> thenEval.success) && (!condEval.value -> elseEval.success);
      in
      {
        inherit success;
        value = if success then if condEval.value then thenEval.value else elseEval.value else null;
      }
    else if _expr == "let" then
      # todo maybe this is possible, but for now i dont know how
      throw
        "evaluating reified 'let' expressions is currently not supported. you can work around this by either inlining the expressions or using let outside of reified functions"
    else if _expr == "with" then
      throw "evaluating reified 'with' expressions is currently not supported. you can work around this by either inlining the expressions or using with outside of reified functions"
    else if _expr == "call" then
      let
        funcEval = eval value.function;
        argsEval = builtins.map (e: eval e) value.args;

        success = funcEval.success && builtins.all (a: a.success) argsEval;
      in
      {
        inherit success;
        value =
          if success then builtins.foldl' (acc: curr: acc curr.value) funcEval.value argsEval else null;
      }
    else if _expr == "update" then
      let
        baseEval = eval value.e1;
        updateEval = eval value.e2;
        success = baseEval.success && updateEval.success;
      in
      {
        inherit success;
        value = if success then baseEval.value // updateEval.value else null;
      }
    else if _expr == "concatLists" then
      let
        fstEval = eval value.e1;
        sndEval = eval value.e2;
        success = fstEval.success && sndEval.success;
      in
      {
        inherit success;
        value = if success then fstEval.value ++ sndEval.value else null;
      }
    else if _expr == "not" then
      let
        exprEval = eval value;
        success = exprEval.success;
      in
      {
        inherit success;
        value = if success then !exprEval.value else null;
      }
    else if _expr == "equals" then
      let
        fstEval = eval value.e1;
        sndEval = eval value.e2;
        success = fstEval.success && sndEval.success;
      in
      {
        inherit success;
        value = if success then fstEval.value == sndEval.value else null;
      }
    else if _expr == "and" then
      let
        fstEval = eval value.e1;
        sndEval = eval value.e2;
        success = fstEval.success && sndEval.success;
      in
      {
        inherit success;
        value = if success then fstEval.value && sndEval.value else null;
      }
    else if _expr == "or" then
      let
        fstEval = eval value.e1;
        sndEval = eval value.e2;
        success = fstEval.success && sndEval.success;
      in
      {
        inherit success;
        value = if success then fstEval.value || sndEval.value else null;
      }
    else if _expr == "implies" then
      let
        fstEval = eval value.e1;
        sndEval = eval value.e2;
        success = fstEval.success && sndEval.success;
      in
      {
        inherit success;
        value = if success then fstEval.value -> sndEval.value else null;
      }
    else if _expr == "notEquals" then
      let
        fstEval = eval value.e1;
        sndEval = eval value.e2;
        success = fstEval.success && sndEval.success;
      in
      {
        inherit success;
        value = if success then fstEval.value != sndEval.value else null;
      }
    else if _expr == "path" then
      let
        isRelative = !pkgs.lib.hasPrefix "/" value;
      in
      if isRelative then
        throw "evaluatiing reified relative paths is not supported"
      else
        {
          success = true;
          value = /. + value;
        }
    else
      throw ("unknown _expr handed to eval: " + _expr);

  toIR_ =
    reifiedFunctions: x: name:
    let
      evalValue = eval x;
    in
    if
      builtins.typeOf x == "set"
      && builtins.hasAttr "_expr" x
      && builtins.hasAttr "value" x
      && evalValue.success
    then
      toIR_ reifiedFunctions evalValue.value name
    # {
    #   value = {
    #     _expr = "value";
    #     value = evalValue.value;
    #   };
    #   reifiedFunctions = reifiedFunctions;
    # }

    else if
      builtins.typeOf x == "set"
      && builtins.hasAttr "_expr" x
      && builtins.hasAttr "value" x
      && x._expr == "attrSet"
      && !evalValue.success
    then
      let
        res = (
          builtins.foldl'
            (
              acc: curr:
              let
                recCall = toIR_ acc.fs curr.value (name + "." + curr.name);
              in

              {
                result = acc.result // {
                  ${curr.name} = recCall.value;
                };
                fs = recCall.reifiedFunctions;
              }
            )
            {
              result = { };
              fs = reifiedFunctions;
            }
            (pkgs.lib.attrsToList x.value.attrs)
        );

      in
      {
        value = res.result;
        reifiedFunctions = res.fs;
      }

    else if

      builtins.typeOf x == "set"
      && builtins.hasAttr "_expr" x
      && builtins.hasAttr "value" x
      && x._expr == "list"
    then
      let
        res =
          builtins.foldl'
            (
              acc: curr:
              let
                recCall = toIR_ acc.fs curr (name + (builtins.toString acc.index));
              in
              {
                result = acc.result ++ [ recCall.value ];
                fs = recCall.reifiedFunctions;
                index = acc.index + 1;
              }
            )
            {
              result = [ ];
              index = 0;
              fs = reifiedFunctions;
            }
            x.value;
      in
      {
        value = res.result;
        reifiedFunctions = res.fs;
      }
    else
      (
        (
          if
            builtins.elem (builtins.typeOf x) [
              "int"
              "float"
              "string"
              "path"
              "bool"
              "null"
            ]
          then
            {
              value = x;
              inherit reifiedFunctions;
            }
          else if builtins.typeOf x == "set" && (!builtins.hasAttr "_expr" x || x._expr != "lambda") then
            let
              res = (
                builtins.foldl'
                  (
                    acc: curr:
                    let
                      recCall = toIR_ acc.fs curr.value (name + "." + curr.name);
                    in
                    {
                      result = acc.result // {
                        ${curr.name} = recCall.value;
                      };
                      fs = recCall.reifiedFunctions;
                    }
                  )
                  {
                    result = { };
                    fs = reifiedFunctions;
                  }
                  (pkgs.lib.attrsToList x)
              );

            in
            {
              value = res.result;
              reifiedFunctions = res.fs;
            }

          else if builtins.typeOf x == "set" && builtins.hasAttr "_expr" x && x._expr == "lambda" then
            if
              builtins.all (f: f.value.f != x) (
                builtins.filter (e: builtins.typeOf e.value.f == "set") (pkgs.lib.attrsToList reifiedFunctions)
              )
            then
              let
                newFunctionId = findNewFunctionName reifiedFunctions name;
                recCall = (
                  toIR_ (
                    reifiedFunctions
                    // {
                      ${newFunctionId} = {
                        id = newFunctionId;
                        f = x;
                      };
                    }

                  ) x.value (name + "inside Lambda")
                );
              in
              {
                value =

                  {
                    _expr = "lambda";
                    value = {
                      implementation = {
                        value = recCall.value;
                        _expr = "lambda";
                      };
                      id = newFunctionId;
                    };
                  };
                inherit (recCall) reifiedFunctions;
              }
            else
              let
                # Find the existing entry in reifiedFunctions that matches 'x'
                existingFunc =
                  pkgs.lib.findFirst (f: f.value.f == x)
                    (throw "Logic error: function found in check but not in findFirst")
                    (builtins.filter (e: builtins.typeOf e.value.f == "set") (pkgs.lib.attrsToList reifiedFunctions));
              in
              {
                # Pass the state through unchanged
                inherit reifiedFunctions;
                # Return a reference to the existing ID
                value = {
                  _expr = "lambdaRef";
                  value = {
                    name = existingFunc.value.id;
                  };
                };
              }

          else if builtins.typeOf x == "list" then
            let
              res =
                builtins.foldl'
                  (
                    acc: curr:
                    let
                      recCall = toIR_ acc.fs curr (name + (builtins.toString acc.index));
                    in
                    {
                      result = acc.result ++ [ recCall.value ];
                      fs = recCall.reifiedFunctions;
                      index = acc.index + 1;
                    }
                  )
                  {
                    result = [ ];
                    index = 0;
                    fs = reifiedFunctions;
                  }
                  x;
            in
            {
              value = res.result;
              reifiedFunctions = res.fs;
            }

          else if builtins.typeOf x == "lambda" then
            if
              builtins.all (f: !builtins.sameFunction f.value.f x) (
                builtins.filter (e: builtins.typeOf e.value.f == "lambda") (pkgs.lib.attrsToList reifiedFunctions)
              )
            then

              let
                newFunctionId = findNewFunctionName reifiedFunctions name;
                recCall = toIR_ (
                  reifiedFunctions
                  // {
                    ${newFunctionId} = {
                      id = newFunctionId;
                      f = x;
                    };
                  }

                ) (builtins.reify x).value name;
              in
              {
                value =

                  {
                    _expr = "lambda";
                    value = {
                      implementation = {
                        _expr = (builtins.reify x)._expr;
                        value = recCall.value;
                      };
                      id = newFunctionId;
                    };
                  };
                inherit (recCall) reifiedFunctions;
              }
            else
              {
                inherit reifiedFunctions;
                value = {
                  _expr = "lambdaRef";
                  value.name =
                    (pkgs.lib.findFirst (f: builtins.typeOf f.value.f == "lambda" && builtins.sameFunction f.value.f x)
                      (throw "no function found but there is a function!?!?!??!??! seems like a bug :/")
                      (pkgs.lib.attrsToList reifiedFunctions)
                    ).value.id;
                };
              }
          else
            throw ("unknown value type handed to toIR" + (builtins.toString (builtins.typeOf x)))
        )
      );

  findNewAttrName =
    attrs: prefix: i:
    let
      attrName = "${prefix}${toString i}";
    in
    if builtins.hasAttr attrName attrs then findNewAttrName attrs prefix (i + 1) else attrName;

  findNewFunctionName = functions: name: findNewAttrName functions (sanitizeFunctionName name) 0;

  sanitizeFunctionName = name: builtins.replaceStrings [ "." " " ] [ "_" "_"] name;

in
value: name: (toIR_ { } value name).value
