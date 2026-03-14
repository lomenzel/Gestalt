{ lib, ... }:

let
  eval =
    {
      _expr ? null,
      value ? throw "value is required",
      name ? "",
      ...
    }@input:
    if _expr == null then
      throw input
    else if _expr == "literal" || _expr == "attrName" then
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
        attrsEval = lib.mapAttrsToList (name: attr: {
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
              lib.listToAttrs (
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
        isRelative = !lib.hasPrefix "/" value;
      in
      if isRelative then
        throw "evaluating reified relative paths is not supported"
      else
        {
          success = true;
          value = /. + value;
        }
    else if _expr == "primop" || _expr == "primopApp" then
      {
        success = false;
        value = null;
      }
    else
      throw ("unknown _expr handed to eval: " + _expr);
in
{
  lib.evaluateAST = eval;
}
