{ config, lib, ... }:
let

  sanitizeVarName = name: if name == "int" then "_int" else name;
  primopToCppName = p: "GestaltCore::gestalt_primop_${builtins.replaceStrings [ "'" ] [ "_" ] p}";
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
                name: value: ''{ "${name}",  ${(toCpp' value reifiedFunctions).text}  }''
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
            ${builtins.concatStringsSep ",\n" (lib.map (elem: (toCpp' elem reifiedFunctions).text) nixExpr)}
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
            (
              if ast.value.arguments.identifier != null then
                "Value ${ sanitizeVarName ast.value.arguments.identifier} = __gestalt_param;\n"
              else
                ""
            )
            + (
              if hasFormals then
                builtins.concatStringsSep "\n" (
                  lib.map (
                    param:
                    if builtins.hasAttr "defaultExpr" param then
                      ''
                        Value ${ sanitizeVarName param.name};
                        try {
                          ${ sanitizeVarName param.name} = __gestalt_param["${ sanitizeVarName param.name}"];
                        } catch(...) {
                          ${ sanitizeVarName param.name} = ${(ASTtoCpp param.defaultExpr reifiedFunctions).text};                    
                        }
                      ''
                    else
                      ''
                        Value ${ sanitizeVarName param.name} = __gestalt_param["${ sanitizeVarName param.name}"];
                      ''
                  ) ast.value.arguments.formals
                )
                + "\n"
                +
                  # --- NEW: Strict parameter checking if ellipsis is false ---
                  (
                    if builtins.hasAttr "ellipsis" ast.value.arguments && ast.value.arguments.ellipsis == false then
                      ''
                        if (__gestalt_param.type == Value::Type::Set) {
                          const auto& _param_map = std::get<Value::Set>(__gestalt_param.value);
                          for (const auto& _kv : _param_map) {
                            if (${
                              if ast.value.arguments.formals == [ ] then
                                "true"
                              else
                                builtins.concatStringsSep " && " (
                                  builtins.map (f: "_kv.first != \"${f.name}\"") ast.value.arguments.formals
                                )
                            }) {
                              throw std::runtime_error("GestaltCore::Value: Unexpected argument '" + _kv.first + "' passed to function");
                            }
                          }
                        }
                      ''
                    else
                      ""
                  )
              else
                ""
            );

          lambdaBody = ''
            ${paramBinding}
            return ${body.text};
          '';
        in
        {
          text =
            if hasName then
              ''
                ([=]() { 
                  auto _rec_func = [=](auto _self, Value __gestalt_param) -> Value {
                    Value ${name} = Value::lambda([_self](Value __inner_param) {
                      return _self(_self, __inner_param);
                    });
                    ${lambdaBody}
                  };
                  return Value::lambda([=](Value __gestalt_param) {
                    return _rec_func(_rec_func, __gestalt_param);
                  });
                }())
              ''
            else
              ''
                Value::lambda([=](Value __gestalt_param) {
                  ${lambdaBody}
                })
              '';
          inherit (body) reifiedFunctions;
        }
      else if ast._expr == "concatString/addition" then
        let
          elements = builtins.map (
            element:
            let
              recCall = ASTtoCpp element reifiedFunctions;
            in
            recCall.text
          ) ast.value;
          folded =
            if elements == [ ] then
              "Value::fromInt(0)"
            else
              builtins.foldl' (acc: curr: "GestaltCore::gestalt_add(${acc}, ${curr})") (builtins.head elements) (
                builtins.tail elements
              );
        in
        {
          text = folded;
          inherit reifiedFunctions;
        }
      else if ast._expr == "var" then
        {
          text = sanitizeVarName ast.value.name;
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
          text = "Value::fromBool(!${v.text}.asBool())";
          inherit (v) reifiedFunctions;
        }
      else if ast._expr == "call" then
        let
          funcAst = ast.value.function;
          funcCpp = ASTtoCpp funcAst reifiedFunctions;
          argsCpp = builtins.map (
            arg:
            let
              recCall = ASTtoCpp arg reifiedFunctions;
            in
            recCall.text
          ) ast.value.args;

          callText = builtins.foldl' (acc: curr: "(${acc})(${curr})") funcCpp.text argsCpp;
        in
        {
          text = callText;
          inherit reifiedFunctions;
        }
      else if ast._expr == "primop" then
        {
          text = primopToCppName ast.value;
          inherit reifiedFunctions;
        }
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
          callText = builtins.foldl' (acc: curr: "(${acc})(${curr})") primopCpp.text argsCpp.value;
        in
        {
          text = callText;
          inherit (argsCpp) reifiedFunctions;
        }
      else if ast._expr == "attrSet" then
        if ast.value.recursive || ast.value.dynamicAttrs != [ ] then
          throw "recursive sets and sets with dynamic attributes not supported in ASTtoCpp"
        else
          {
            text = ''
              Value::fromSet({
                ${builtins.concatStringsSep ",\n" (
                  lib.mapAttrsToList (
                    name: value: ''{ "${name}", ${(ASTtoCpp value reifiedFunctions).text} }''
                  ) ast.value.attrs
                )}
              })
            '';
            inherit reifiedFunctions;
          }
      else if ast._expr == "select" then
        let
          setCpp = ASTtoCpp ast.value.expression reifiedFunctions;
          pathCpp = builtins.map (p: "[${(ASTtoCpp p reifiedFunctions).text}]") ast.value.path;
          defaultCpp = ASTtoCpp ast.value.default reifiedFunctions;
        in
        {
          text =
            if builtins.hasAttr "default" ast.value then
              ''
                ([=]() {
                  try {
                    return ${setCpp.text}${builtins.concatStringsSep "" pathCpp};
                  } catch(...) {
                    return ${defaultCpp.text};
                  }
                }())
              ''
            else
              ''
                ${setCpp.text}${builtins.concatStringsSep "" pathCpp}
              '';
          inherit reifiedFunctions;
        }
      else if ast._expr == "update" then
        let
          baseCpp = ASTtoCpp ast.value.e1 reifiedFunctions;
          updateCpp = ASTtoCpp ast.value.e2 reifiedFunctions;
        in
        {
          text = "${baseCpp.text}.update(${updateCpp.text})";
          inherit reifiedFunctions;
        }
      else if ast._expr == "concatLists" then
        let
          aCpp = ASTtoCpp ast.value.e1 reifiedFunctions;
          bCpp = ASTtoCpp ast.value.e2 reifiedFunctions;
        in
        {
          text = "${aCpp.text}.concat(${bCpp.text})";
          inherit reifiedFunctions;
        }
      else if ast._expr == "list" then
        let
          elementsCpp = builtins.map (e: ASTtoCpp e reifiedFunctions) ast.value;
        in
        {
          text = ''
            Value::fromList({
              ${builtins.concatStringsSep ",\n" (
                lib.map (elem: (ASTtoCpp elem reifiedFunctions).text) ast.value
              )}
            })
          '';
          inherit reifiedFunctions;
        }
      else if ast._expr == "equals" then
        let
          aCpp = ASTtoCpp ast.value.e1 reifiedFunctions;
          bCpp = ASTtoCpp ast.value.e2 reifiedFunctions;
        in
        {
          text = "Value::fromBool(${aCpp.text} == ${bCpp.text})";
          inherit reifiedFunctions;
        }
      else if ast._expr == "notEquals" then
        let
          aCpp = ASTtoCpp ast.value.e1 reifiedFunctions;
          bCpp = ASTtoCpp ast.value.e2 reifiedFunctions;
        in
        {
          text = "Value::fromBool(!(${aCpp.text} == ${bCpp.text}))";
          inherit reifiedFunctions;
        }
      else if ast._expr == "and" then
        let
          aCpp = ASTtoCpp ast.value.e1 reifiedFunctions;
          bCpp = ASTtoCpp ast.value.e2 reifiedFunctions;
        in
        {
          text = "Value::fromBool(${aCpp.text}.asBool() && ${bCpp.text}.asBool())";
          inherit reifiedFunctions;
        }
      else if ast._expr == "or" then
        let
          aCpp = ASTtoCpp ast.value.e1 reifiedFunctions;
          bCpp = ASTtoCpp ast.value.e2 reifiedFunctions;
        in
        {
          text = "Value::fromBool(${aCpp.text}.asBool() || ${bCpp.text}.asBool())";
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
