{ config, lib, ... }:
let
  toCpp' =
    nixExpr: reifiedFunctions:
    if
      builtins.elem (builtins.typeOf nixExpr) [
        "int"
        "float"
        "string"
        "bool"
        "null"
      ]
    then
      {
        text =
          if builtins.typeOf nixExpr == "int" then
            "Value::fromInt(${toString nixExpr})"
          else if builtins.typeOf nixExpr == "float" then
            "Value::fromFloat(${builtins.toJSON nixExpr})"
          else if builtins.typeOf nixExpr == "string" then
            "Value::fromString(${builtins.toJSON nixExpr})"
          else if builtins.typeOf nixExpr == "bool" then
            "Value::fromBool(${builtins.toJSON nixExpr})"
          else
            "Value::null()";
        inherit reifiedFunctions;
      }
    else if builtins.typeOf nixExpr == "lambda" then
      let
        newFunctionName = config.lib.findNewFunctionName reifiedFunctions;
        isOld = builtins.any (builtins.sameFunction nixExpr) (lib.attrValues reifiedFunctions);
        oldFunctionName =
          (lib.findFirst (e: builtins.sameFunction nixExpr e.value) null (lib.attrsToList reifiedFunctions))
          .name;
      in
      if isOld then
        {
          text = oldFunctionName;
          inherit reifiedFunctions;
        }
      else
        let
          newReifiedFunctions = reifiedFunctions // {
            ${newFunctionName} = nixExpr;
          };
          translatedAst = ASTtoCpp (
            (builtins.reify nixExpr) // { name = newFunctionName; }
          ) newReifiedFunctions;
        in
        {
          inherit (translatedAst) text reifiedFunctions;
        }
    else if builtins.typeOf nixExpr == "set" then
      {
        text = ''
          Value::fromSet({
            ${builtins.concatStringsSep ",\n" (
              lib.mapAttrsToList (
                name: value: "  { " + (toCpp' name reifiedFunctions).text + ", " + (toCpp' value reifiedFunctions).text + " }"
              ) nixExpr
            )}
          })
        '';
        inherit reifiedFunctions;
      }
    
    else if builtins.typeOf nixExpr == "list" then
      {
        text = ''
          Value::fromList({
            ${builtins.concatStringsSep ",\n" (
              lib.map (elem: (toCpp' elem reifiedFunctions).text) nixExpr
            )}
          })
        '';
        inherit reifiedFunctions;
      }
      else
      builtins.throw "unsupported type ${builtins.typeOf nixExpr} in toCpp";

  ASTtoCpp =
    ast: reifiedFunctions:
    if builtins.typeOf ast != "set" then
      throw ast
    else
      let
        evaluationResult = config.lib.evaluateAST ast;

      in
      if evaluationResult.success then
        toCpp' evaluationResult.value reifiedFunctions
      else if ast._expr == "lambda" then
        let
          body = ASTtoCpp ast.value.body reifiedFunctions;
          hasName = builtins.hasAttr "name" ast;
          name = if hasName then ast.name else "";
          hasFormals = builtins.hasAttr "formals" ast.value.arguments;
          paramBinding =
            if ast.value.arguments.identifier != null then
              "Value ${ast.value.arguments.identifier} = __gestalt_param;"
            else if hasFormals then
              builtins.concatStringsSep "\n" (
                lib.map (
                  param:
                  if builtins.hasAttr "defaultExpr" param then
                    throw "default expressions not supported in lambda parameters in ASTtoCpp"
                  else
                    "Value ${param.name} = __gestalt_param[\"${param.name}\"];"
                ) ast.value.arguments.formals
              )
            else
              "";
          lambdaBody = ''
            ${paramBinding}
            return ${body.text};
          '';
        in
        {
          text =
            if hasName then
              ''
                ([]() { 
                  GestaltNixValue ${name};
                  ${name} = GestaltNixValue::lambda([&](GestaltNixValue __gestalt_param) {
                    ${lambdaBody}
                  });
                  return ${name};
                }())
              ''
            else
              ''
                GestaltNixValue::lambda([&](GestaltNixValue __gestalt_param) {
                  ${lambdaBody}
                })
              '';
          inherit (body) reifiedFunctions;
        }
      else if ast._expr == "concatString/addition" then
        let
          elements =
            builtins.foldl'
              (
                acc: curr:
                let
                  recCall = ASTtoCpp curr acc.reifiedFunctions;
                in
                {
                  value = acc.value ++ [ recCall.text ];
                  inherit (recCall) reifiedFunctions;
                }
              )
              {
                value = [ ];
                inherit reifiedFunctions;
              }
              ast.value;
          parts = elements.value;
          folded =
            if parts == [ ] then
              "GestaltNixValue::fromInt(0)"
            else
              builtins.foldl' (acc: curr: "gestalt_add(${acc}, ${curr})") (builtins.head parts) (
                builtins.tail parts
              );
        in
        {
          text = folded;
          inherit (elements) reifiedFunctions;
        }
      else if ast._expr == "var" then
        {
          text = ast.value.name;
          inherit reifiedFunctions;
        }
      else if ast._expr == "if" then
        let
          condition = ASTtoCpp ast.value.condition reifiedFunctions;
          thenBranch = ASTtoCpp ast.value.${"then"} condition.reifiedFunctions;
          elseBranch = ASTtoCpp ast.value.${"else"} thenBranch.reifiedFunctions;
        in
        {
          text = "(${condition.text}.asBool() ? ${thenBranch.text} : ${elseBranch.text})";
          inherit (elseBranch) reifiedFunctions;
        }
      else if ast._expr == "not" then
        let
          v = ASTtoCpp ast.value reifiedFunctions;
        in
        {
          text = "GestaltNixValue::fromBool(!${v.text}.asBool())";
          inherit (v) reifiedFunctions;
        }
      else if ast._expr == "call" then
        let
          funcAst = ast.value.function;
          funcCpp = ASTtoCpp funcAst reifiedFunctions;
          argsCpp =
            builtins.foldl'
              (
                acc: curr:
                let
                  recCall = ASTtoCpp curr acc.reifiedFunctions;
                in
                {
                  value = acc.value ++ [ recCall.text ];
                  inherit (recCall) reifiedFunctions;
                }
              )
              {
                value = [ ];
                inherit (funcCpp) reifiedFunctions;
              }
              ast.value.args;
          argsList = argsCpp.value;
          primopMap = {
            "__sub" = "gestalt_sub";
            "__lessThan" = "gestalt_lessThan";
          };
          isPrimop =
            funcAst._expr == "var"
            && builtins.hasAttr funcAst.value.name primopMap
            && builtins.length argsList == 2;
          primopText =
            if isPrimop then
              "${primopMap.${funcAst.value.name}}(${builtins.elemAt argsList 0}, ${builtins.elemAt argsList 1})"
            else
              null;
          callText = builtins.foldl' (acc: curr: "(${acc}).call(${curr})") funcCpp.text argsList;
        in
        {
          text = if isPrimop then primopText else callText;
          inherit (argsCpp) reifiedFunctions;
        }
      else if ast._expr == "primop" then
        throw "unsupported primop ${ast.value} in ASTtoCpp"
      else if ast._expr == "primopApp" then
        let
          primopCpp = ASTtoCpp {
            _expr = "primop";
            value = ast.value.primop;
          } reifiedFunctions;
          argsCpp =
            builtins.foldl'
              (
                acc: curr:
                let
                  recCall = toCpp' curr acc.reifiedFunctions;
                in
                {
                  value = acc.value ++ [ recCall.text ];
                  inherit (recCall) reifiedFunctions;
                }
              )
              {
                value = [ ];
                inherit (primopCpp) reifiedFunctions;
              }
              ast.value.appliedArgs;
          callText = builtins.foldl' (acc: curr: "(${acc}).call(${curr})") primopCpp.text argsCpp.value;
        in
        {
          text = callText;
          inherit (argsCpp) reifiedFunctions;
        }
      else if ast._expr == "attrSet" then
        if ast.value.recursive || ast.value.dynamicAttrs != [] then
          throw "recursive sets and sets with dynamic attributes not supported in ASTtoCpp"
        else
        {
          text = ''
            Value::fromSet({
              ${builtins.concatStringsSep ",\n" (
                lib.mapAttrsToList (
                  name: value: "  { " + (toCpp' name reifiedFunctions).text + ", " + (toCpp' value reifiedFunctions).text + " }"
                ) ast.value.attrs
              )}
            })
          '';
          inherit reifiedFunctions;
        }
      else
        throw "Unsupported AST node in ASTtoCpp: ${ast._expr}";
in
{
  lib.toCpp =
    nixExpr:
    let
      inherit (toCpp' nixExpr { }) text reifiedFunctions;
    in
    text;
}
