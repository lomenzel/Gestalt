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
      else
        builtins.throw ("unsupported primop in JS conversion: " + primop)

    else
      ''
        function ${func.name}(param) {
          return  ${exprToJS func.value.body}
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

in
{
  inherit toJS exprToJS;
}
