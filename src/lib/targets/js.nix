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
          function ${name}(param1, param2) {
            return (param1 < param2);
          }
        ''

      else if primop == "sub" then
        ''
          function ${name}(param1, param2) {

            if(typeof param1 !== "number" || typeof param2 !== "number") {
              throw new TypeError(`sub received non-number parameters: ${"$"}{param1}, ${"$"}{param2}`);
            }
            return (param1 - param2);
          }''
      else if primop == "toString" then
        ''
          function ${name}(param) {
            return param.toString();
          }
        ''

      else if primop == "mul" then
        ''
          function ${name}(param1, param2) {
            return (param1 * param2);
          }
        ''
      else if primop == "div" then
        ''
          function ${name}(param1, param2) {
            return (param1 / param2);
          }
        ''
      else if primop == "genList" then
        ''
          function ${name}(func, count) {
            console.log("genList called with count:", count, "and func:", func);
            const result = [];
            for (let i = 0; i < count; i++) {
              console.log("genList iteration:", i);
              result.push(func(i));
              console.log("genList intermediate result:", result);
            }
            console.log("returning from genList:", result);
            return result;
          }
        ''
        else if primop == "concatMap" then
        ''
          function ${name}(func, list) {
            console.log("concatMap called with list:", list, "and func:", func);
            const result = [];
            for (let i = 0; i < list.length; i++) {
              const sublist = func(list[i]);
              for (let j = 0; j < sublist.length; j++) {
                result.push(sublist[j]);
              }
            }
            console.log("returning from concatMap:", result);
            return result;
          }
        ''
          else if primop == "filter" then
        ''
          function ${name}(func, list) {
            const result = [];
            for (let i = 0; i < list.length; i++) {
              if (func(list[i])) {
                result.push(list[i]);
              }
            }
            return result;
          }
        ''
          else if primop == "elemAt" then

        ''
          function ${name}(list, index) {
            return list[index];
          }
        ''

          else if primop == "length" then
        ''
          function ${name}(list) {
            return list.length;
          }
        ''
          else
            if primop == "all" then
              ''
                function ${name}(func, list) {
                  for (let i = 0; i < list.length; i++) {
                    if (!func(list[i])) {
                      return false;
                    }
                  }
                  return true;
                }
              '' else
          if primop == "elem" then
            ''
              function ${name}(item, list) {
                return elem(item, list);
              }
            ''
          else if primop == "map" then
            ''
              function ${name}(func, list) {
                const result = [];
                for (let i = 0; i < list.length; i++) {
                  result.push(func(list[i]));
                }
                return result;
              }
            ''
            else
        builtins.throw ("unsupported primop in JS conversion: " + primop)

    else
      ''
        function ${func.name}(param) {
          console.log("Function ${func.name} called with param:", param);
          result =  ${exprToJS func.value.body}
          console.log("Function ${func.name} returning:", result);
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
        if expr._expr == "param" then
          "(param"
          + pkgs.lib.concatStringsSep "" ((builtins.map (field: ("." + field)) (expr.field or [ ])))
          + ")"

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

        else if expr._expr == "call" then
          let
            funcJS = exprToJS expr.value.function;
            argsJS = builtins.map exprToJS expr.value.args;
          in
          funcJS + "(" + pkgs.lib.concatStringsSep ", " argsJS + ")"

        else if expr._expr == "lambdaRef" then
          expr.value.name
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
