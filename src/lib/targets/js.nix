pkgs:
let
  toJS =
    func:
    if
      builtins.typeOf func.value.body == "set"
      && builtins.hasAttr "_expr" func.value.body
      && func.value.body._expr == "primop"
    then
      let
        primop = func.value.body.value;
        name = func.name;
      in

      if primop == "lessThan" then
        ''
          function ${name}(scope) {
            const __arg1 = scope.__value;
            return function(scope) {
              return (__arg1 < scope.__value);
            };
          }
        ''

      else if primop == "sub" then
        ''
          function ${name}(scope) {
            const __arg1 = scope.__value;
            return function(scope) {
              return (__arg1 - scope.__value);
            };
          }
        ''
      else if primop == "toString" then
        ''
          function ${name}(scope) {
            return scope.__value.toString();
          }
        ''

      else if primop == "mul" then
        ''
          function ${name}(scope) {
            const __arg1 = scope.__value;
            return function(scope) {
              return (__arg1 * scope.__value);
            };
          }
        ''
      else if primop == "div" then
        ''
          function ${name}(scope) {
            const __arg1 = scope.__value;
            return function(scope) {
              return (__arg1 / scope.__value);
            };
          }
        ''
      else if primop == "genList" then
        ''
          function ${name}(scope) {
            const func = scope.__value;
            return function(scope) {
              const count = scope.__value;
              const result = [];
              for (let i = 0; i < count; i++) {
                result.push(func({...scope, __value: i}));
              }
              return result;
            };
          }
        ''
        else if primop == "concatMap" then
        ''
          function ${name}(scope) {
            const func = scope.__value;
            return function(scope) {
              const list = scope.__value;
              const result = [];
              for (let i = 0; i < list.length; i++) {
                const sublist = func({...scope, __value: list[i]});
                for (let j = 0; j < sublist.length; j++) {
                  result.push(sublist[j]);
                }
              }
              return result;
            };
          }
        ''
          else if primop == "filter" then
        ''
          function ${name}(scope) {
            const func = scope.__value;
            return function(scope) {
              const list = scope.__value;
              const result = [];
              for (let i = 0; i < list.length; i++) {
                if (func({...scope, __value: list[i]})) {
                  result.push(list[i]);
                }
              }
              return result;
            };
          }
        ''
          else if primop == "elemAt" then

        ''
          function ${name}(scope) {
            const list = scope.__value;
            return function(scope) {
              return list[scope.__value];
            };
          }
        ''

          else if primop == "length" then
        ''
          function ${name}(scope) {
            return scope.__value.length;
          }
        ''
          else
            if primop == "all" then
              ''
                function ${name}(scope) {
                  const func = scope.__value;
                  return function(scope) {
                    const list = scope.__value;
                    for (let i = 0; i < list.length; i++) {
                      if (!func({...scope, __value: list[i]})) {
                        return false;
                      }
                    }
                    return true;
                  };
                }
              '' else
          if primop == "elem" then
            ''
              function ${name}(scope) {
                const item = scope.__value;
                return function(scope) {
                  return elem(item, scope.__value);
                };
              }
            ''
          else if primop == "map" then
            ''
              function ${name}(scope) {
                const func = scope.__value;
                return function(scope) {
                  const list = scope.__value;
                  const result = [];
                  for (let i = 0; i < list.length; i++) {
                    result.push(func({...scope, __value: list[i]}));
                  }
                  return result;
                };
              }
            ''
            else
        builtins.throw ("unsupported primop in JS conversion: " + primop)

    else
      let
        hasIdentifier = func.value ? arguments && func.value.arguments.identifier or null != null;
        identifierName = if hasIdentifier then func.value.arguments.identifier else null;
        identifierExtraction = if hasIdentifier then
          "scope = {...scope, ${identifierName}: scope.__value};\n          "
        else "";
      in
      ''
        function ${func.name}(scope) {
          ${identifierExtraction}result =  ${exprToJS func.value.body}
          return result;
        }
      '';

  exprToJS =
    expr:
    (
      if
        builtins.elem (builtins.typeOf expr) [
          "int"
          "string"
          "float"
        ]
      then
        builtins.toJSON expr

      else if builtins.typeOf expr == "set" && !builtins.hasAttr "_expr" expr then

        let
          jsFields = pkgs.lib.mapAttrsToList (key: value: "\"" + key + "\": " + (exprToJS value)) expr;
        in
        "{" + pkgs.lib.concatStringsSep ", " jsFields + "}"

      else if builtins.typeOf expr == "list" then
        let
          jsItems = builtins.map exprToJS expr;
        in
        "[" + pkgs.lib.concatStringsSep ", " jsItems + "]"

      else if builtins.typeOf expr == "set" && builtins.hasAttr "_expr" expr then
        if expr._expr == "scopeRef" then
          "(scope.${expr.value.name}${
            pkgs.lib.concatStringsSep "" ((builtins.map (field: (".${field}")) (expr.value.field or [ ])))
          })"

        else if expr._expr == "update" then
          let
            baseJS = exprToJS expr.value.e1;
            updatesJS = exprToJS expr.value.e2;
          in
          ''
            { ...${baseJS}, ...${updatesJS}}
          ''

        else if expr._expr == "concatString/addition" then
          let
            jsItems = builtins.map exprToJS expr.value;
          in
          jsItems |> pkgs.lib.concatStringsSep " + "

        else if expr._expr == "select" then
          "((${exprToJS expr.value.expression}).${pkgs.lib.concatStringsSep "." expr.value.path})"

        else if expr._expr == "scope" then
          "scope"

        else if expr._expr == "call" then
          let
            funcJS = exprToJS expr.value.function;
            argsJS = builtins.map exprToJS expr.value.args;
          in
          # Curried function calls: f(arg1)(arg2)(arg3) instead of f(arg1, arg2, arg3)
          funcJS + pkgs.lib.concatStringsSep "" (builtins.map (arg: "(" + arg + ")") argsJS)

        else if expr._expr == "lambdaRef" then
          "((_scope) =>{ return ${expr.value.name}( {...scope, ..._scope} )})"
        else if expr._expr == "if" then
          let
            condJS = exprToJS expr.value.condition;
            thenJS = exprToJS expr.value.${"then"};
            elseJS = exprToJS expr.value.${"else"};
          in
          "(" + condJS + " ? " + thenJS + " : " + elseJS + ")"

        else if expr._expr == "equals" then
          let
            e1JS = exprToJS expr.value.e1;
            e2JS = exprToJS expr.value.e2;
          in
          "(" + e1JS + " === " + e2JS + ")"

        else if expr._expr == "not" then
          let
            eJS = exprToJS expr.value;
          in
          "(!(" + eJS + "))"

        else if expr._expr == "concatLists" then
          let
            e1JS = exprToJS expr.value.e1;
            e2JS = exprToJS expr.value.e2;
          in
          "([ ..." + e1JS + ", ..." + e2JS + " ])"

        else
          builtins.throw (
            "unsupported special expression in JS conversion: "
            + expr._expr
            + ". Value: "
            + builtins.toJSON expr
          )

      else
        builtins.throw (
          "unsupported expression type in JS conversion: "
          + builtins.typeOf expr
          + ". Value: "
          + builtins.toJSON expr
        )
    );

    generalHelpers = builtins.readFile ./generalHelperJsFunctions.js;

in
{
  inherit toJS exprToJS generalHelpers;
}
