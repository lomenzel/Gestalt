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

      else if primop == "foldl'" then
        ''
          function ${name}(scope) {
            const op = scope.__value;
            return function(scope) {
              let acc = scope.__value;
              return function(scope) {
                const list = scope.__value;
                for (let i = 0; i < list.length; i++) {
                  // Call the operator with the current accumulator
                  const opWithAcc = op({ ...scope, __value: acc });
                  // Then call the result with the current list item
                  acc = opWithAcc({ ...scope, __value: list[i] });
                }
                return acc;
              };
            };
          }
        ''
      else if primop == "typeOf" then
        ''
          function ${name}(scope) {
            const e = scope.__value;

            if (e === null) return "null";

            const t = typeof e;

                      
            if (t === "boolean") return "bool";
            if (t === "string") return "string";
            if (t === "number") {
              return Number.isInteger(e) ? "int" : "float";
            }
            if (t === "function") return "lambda";

            if (Array.isArray(e)) return "list";

            if (t === "object") return "set";

            throw new Error("Unsupported type");
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
      else if primop == "all" then
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
        ''
      else if primop == "elem" then
        ''
          function ${name}(scope) {
            const item = scope.__value;
            return function(scope) {
              return elem(item, scope.__value);
            };
          }
        ''
      else if primop == "hasAttr" then
        ''
          function ${name}(scope) {
            const attr = scope.__value;
            return function(scope) {
              return Object.prototype.hasOwnProperty.call(scope.__value, attr);
            };
          }
        ''
      else if primop == "fromJSON" then
        ''
          function ${name}(scope) {
            return JSON.parse(scope.__value);
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
      else if primop == "concatStringsSep" then
        ''
          function ${name}(scope) {
            const sep = scope.__value;
            return function(scope) {
              return scope.__value.join(sep);
            };
          }
        ''
      else if primop == "head" then
        ''
          function ${name}(scope) {
            return scope.__value[0];
          }
        ''
      else if primop == "toJSON" then
        ''
          function ${name}(scope) {
            return JSON.stringify(scope.__value);
          }
        ''
      else if primop == "trace" then
        ''
          function ${name}(scope) {
            const message = scope.__value;
            return function(scope) {
              console.log("[TRACE] " + message, scope.__value);
              return scope.__value;
            };
          }
        ''
      else
        builtins.throw ("unsupported primop in JS conversion: " + primop)

    else
      let
        hasIdentifier = func.value ? arguments && func.value.arguments.identifier or null != null;
        identifierName = if hasIdentifier then func.value.arguments.identifier else null;
        identifierExtraction =
          if hasIdentifier then "scope = {...scope, ${identifierName}: scope.__value};\n          " else "";
      in
      ''
        function ${func.name}(scope) {
          ${identifierExtraction}
          result =  ${exprToJS func.value.body}
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
          "((_scope) =>{ return ${expr.value.name}( {..._scope, ...scope, __value: _scope.__value} )})"
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
          "(deepEqual(${e1JS}, ${e2JS}))"

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
        else if expr._expr == "and" then
          let
            e1JS = exprToJS expr.value.e1;
            e2JS = exprToJS expr.value.e2;
          in
          "((" + e1JS + ") && (" + e2JS + "))"
        else
          builtins.throw (
            "unsupported special expression in JS conversion: "
            + expr._expr
            + ". Value: "
            + builtins.toJSON expr
          )

      else if builtins.typeOf expr == "bool" then
        "(${builtins.toJSON expr})"
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
