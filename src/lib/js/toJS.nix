{ config, lib, ... }:
let
  jsEquals = builtins.readFile ./equals.js;

  toJS' =
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
        text = builtins.toJSON nixExpr;
        inherit reifiedFunctions;
      }
    else if builtins.typeOf nixExpr == "list" then
      {
        text =
          # todo maybe this is bad because it duplicates reification
          "[ "
          + builtins.concatStringsSep ", " (builtins.map (x: (toJS' x reifiedFunctions).text) nixExpr)
          + " ]";
        inherit reifiedFunctions;
      }
    else if builtins.typeOf nixExpr == "set" then
      {
        text = ''
          { 
            ${builtins.concatStringsSep ", " (
              lib.mapAttrsToList (
                key: value: "${builtins.toJSON key}: ${(toJS' value reifiedFunctions).text}"
              ) nixExpr
            )}
          }
        '';
        inherit reifiedFunctions;
      }
    else if builtins.typeOf nixExpr == "lambda" then
      let
        newFunctionName = config.lib.findNewFunctionName reifiedFunctions;
        isOld = builtins.any (builtins.sameFunction nixExpr) ((lib.attrValues reifiedFunctions));
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
          translatedAst = ASTtoJS (
            (builtins.reify nixExpr) // { name = newFunctionName; }
          ) newReifiedFunctions;
        in
        {
          inherit (translatedAst) text reifiedFunctions;
        }
    else
      builtins.throw "unsupported type ${builtins.typeOf nixExpr} in toJS";

  ASTtoJS =
    ast: reifiedFunctions:
    if builtins.typeOf ast != "set" then
      throw ast
    else
      let
        evaluationResult = config.lib.evaluateAST ast;
      in
      if evaluationResult.success then
        toJS' evaluationResult.value reifiedFunctions
      else if ast._expr == "lambda" then
        let
          body = ASTtoJS ast.value.body reifiedFunctions;
        in
        {
          text = ''
            (function ${if builtins.hasAttr "name" ast then ast.name else ""}(__gestalt_param) {
              ${
                # identifier
                if ast.value.arguments.identifier != null then
                  "const ${ast.value.arguments.identifier} = __gestalt_param;"
                else
                  ""
              }${
                if builtins.hasAttr "formals" ast.value.arguments then
                  (lib.concatMapStringsSep "\n" (formal: ''
                    const ${formal.name} = __gestalt_param.${formal.name};
                    if (${formal.name} === undefined) {
                      throw new Error("GestaltCore::Value: Field '${formal.name}' not found");
                    }
                  '') ast.value.arguments.formals)
                  + (
                    if builtins.hasAttr "ellipsis" ast.value.arguments && ast.value.arguments.ellipsis == false then
                      ''
                        for (const _k of Object.keys(__gestalt_param)) {
                          if (![${
                            builtins.concatStringsSep ", " (builtins.map (f: ''"${f.name}"'') ast.value.arguments.formals)
                          }].includes(_k)) {
                            throw new Error("GestaltCore::Value: Unexpected argument '" + _k + "' passed to function");
                          }
                        }
                      ''
                    else
                      ""
                  )

                else
                  ""
              }
              
              return ${body.text}
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
                  recCall = ASTtoJS curr acc.reifiedFunctions;
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
        in
        {
          text = ''
            (${lib.concatStringsSep " + " elements.value})
          '';
          inherit reifiedFunctions;
        }
      else if ast._expr == "var" then
        {
          text = ast.value.name;
          inherit reifiedFunctions;
        }
      else if ast._expr == "if" then
        let
          condition = ASTtoJS ast.value.condition reifiedFunctions;
          thenBranch = ASTtoJS ast.value.${"then"} reifiedFunctions;
          elseBranch = ASTtoJS ast.value.${"else"} reifiedFunctions;
        in
        {
          text = ''
            (${condition.text} ? ${thenBranch.text} : ${elseBranch.text})
          '';
          inherit reifiedFunctions;
        }
      else if ast._expr == "not" then
        let
          v = ASTtoJS ast.value reifiedFunctions;
        in
        {
          text = ''
            (!${v.text})
          '';
          inherit reifiedFunctions;
        }
      else if ast._expr == "call" then
        let
          funcJS = ASTtoJS ast.value.function reifiedFunctions;
          argsJS = lib.map (arg: ASTtoJS arg reifiedFunctions) ast.value.args;
        in
        {
          text = ''
            ${funcJS.text}${lib.concatStringsSep "" (builtins.map (a: "(${a.text})") argsJS)}
          '';
          inherit reifiedFunctions;
        }
      else if ast._expr == "primop" then
        if builtins.hasAttr ast.value primops then
          {
            text = "(${primops.${ast.value}})";
            inherit reifiedFunctions;
          }
        else
          throw "unsupported primop ${ast.value} in ASTtoJS"
      else if ast._expr == "primopApp" then
        {
          text = ''
            (${
              (ASTtoJS {
                _expr = "primop";
                value = ast.value.primop;
              } reifiedFunctions).text
            }${
              lib.concatStringsSep "" (
                builtins.map (arg: "(${(toJS' arg reifiedFunctions).text})") ast.value.appliedArgs
              )
            })
          '';
          reifiedFunctions = reifiedFunctions;
        }
      else if ast._expr == "attrSet" then
        if ast.value.recursive || ast.value.dynamicAttrs != [ ] then
          throw "recursive and dynamic attrSets are not supported in ASTtoJS yet"
        else
          {
            text = ''
              { ${
                builtins.concatStringsSep ", " (
                  lib.mapAttrsToList (
                    key: value: "${builtins.toJSON key}: ${(ASTtoJS value reifiedFunctions).text}"
                  ) ast.value.attrs
                )
              } }
            '';
            inherit reifiedFunctions;
          }
      else if ast._expr == "select" then
        let
          exprJS = (ASTtoJS ast.value.expression reifiedFunctions).text;
          pathJS = builtins.map (pathExpr: "[${(ASTtoJS pathExpr reifiedFunctions).text}]") ast.value.path;
          defaultJS = (ASTtoJS ast.value.default reifiedFunctions).text;

        in
        {
          text = ''
            ((()=>{
              let result = undefined;
              try {
                result = ${exprJS}${lib.concatStringsSep "" pathJS};
              } catch (e) {
                ${
                  if builtins.hasAttr "default" ast.value then
                    ''
                      result = ${defaultJS};
                    ''
                  else
                    ''
                      throw e;
                    ''
                }
                }
              if (result === undefined) {
                ${
                  if builtins.hasAttr "default" ast.value then
                    "return ${defaultJS};"
                  else
                    ''
                      throw new Error("GestaltCore::Value: Select failed: " + JSON.stringify({
                        expression: ${exprJS},
                        path: ${lib.concatStringsSep "" pathJS}
                      }));
                    ''
                }

              }
              return result;
            })())
          '';
          inherit reifiedFunctions;
        }
      else if ast._expr == "update" then
        let
          baseJS = ASTtoJS ast.value.e1 reifiedFunctions;
          updatesJS = ASTtoJS ast.value.e2 reifiedFunctions;
        in
        {
          text = "{ ...${baseJS.text}, ...${updatesJS.text} }";
          inherit reifiedFunctions;
        }
      else if ast._expr == "concatLists" then
        let
          e1JS = ASTtoJS ast.value.e1 reifiedFunctions;
          e2JS = ASTtoJS ast.value.e2 reifiedFunctions;
        in
        {
          text = "[...${e1JS.text},...${e2JS.text}]";
          inherit reifiedFunctions;
        }
      else if ast._expr == "list" then
        {
          text = ''
            [${lib.concatStringsSep "," (builtins.map (e: (ASTtoJS e reifiedFunctions).text) ast.value)}]
          '';
          inherit reifiedFunctions;
        }
      else if ast._expr == "equals" then
        {
          text = ''
            (${jsEquals}(${(ASTtoJS ast.value.e1 reifiedFunctions).text})(${(ASTtoJS ast.value.e2 reifiedFunctions).text}))
          '';
          inherit reifiedFunctions;
        }
      else if ast._expr == "and" then
        let
          left = ASTtoJS ast.value.e1 reifiedFunctions;
          right = ASTtoJS ast.value.e2 reifiedFunctions;
        in
        {
          text = ''
            (${left.text} && ${right.text})
          '';
          inherit reifiedFunctions;
        }
      else if ast._expr == "or" then
        let
          left = ASTtoJS ast.value.e1 reifiedFunctions;
          right = ASTtoJS ast.value.e2 reifiedFunctions;
        in
        {
          text = ''
            (${left.text} || ${right.text})
          '';
          inherit reifiedFunctions;
        }
      else if ast._expr == "notEquals" then
        {

          text = ''
            (!(${jsEquals}(${(ASTtoJS ast.value.e1 reifiedFunctions).text})(${(ASTtoJS ast.value.e2 reifiedFunctions).text})))
          '';
          inherit reifiedFunctions;

        }

      else
        throw "Unsupported AST node in ASTtoJS: ${ast._expr}";

  primops = {
    sub = "a=>b=>(a - b)";
    lessThan = "a=>b=>(a < b)";
    elemAt = ''
      list=>index=>{
        if (list.length < index)
          throw new Error("index out of bounds");
        if (typeof index !== "number")
          throw new Error("index has to be a number");
        return list.at(index);
      }
    '';
    filter = "func=>list=>list.filter(func)";
    all = "func=>list=>list.every(func)";
    elem = "item=>list=>list.some((${jsEquals}(item)))";
    concatMap = "func=>list=>list.flatMap(func)";
    map = "func=>list=>list.map(func)";
    # todo negative count should throw
    genList = "func=>count=>Array.from({ length: count }, (_, i) => func(i))";
    foldl' = "op=>acc=>list=>list.reduce((acc, curr)=>op(acc)(curr), acc)";
    typeOf = ''
      e=>{
        if (e === null) return "null";
        const t = typeof e;
        if (t === "boolean") return "bool";
        if (t === "string") return "string";
        if (t === "number")
          return Number.isInteger(e) ? "int" : "float";
        if (t === "function") return "lambda";
        if (Array.isArray(e)) return "list";
        if (t === "object") return "set";
        throw new Error("Unsupported type " + t);  
      }
    '';
    toString = "e=>(e === null ? '' : e.toString())";
    toJSON = "e=>JSON.stringify(e)";
    concatStringsSep = "sep=>list=>list.join(sep)";
    fromJSON = "s=>JSON.parse(s)";
    head = "list=>list[0]";
    trace = ''
      msg=>val=>{
        console.log("[TRACE]" + msg, val);
        return val;
      }
    '';
    length = "e=>e.length";
    mul = "a=>b=>(a * b)";
    hasAttr = "attr=>s=>Object.prototype.hasOwnProperty.call(s, attr)";
    div = ''
      a=>b=>{
        if (typeof a !== "number" || typeof b !== "number") {
          throw new Error("gestalt_primop_div: both arguments must be numbers");
        }
        if (Number.isInteger(a) && Number.isInteger(b)) {
          if (b === 0) throw new Error("gestalt_primop_div: division by zero");
          return Math.trunc(a / b);
        }
        if (b === 0) throw new Error("gestalt_primop_div: division by zero");
        return (a / b);
      }
    '';
    any = "func=>list=>list.some(func)";
    warn = ''
      msg=>val=>{
            console.warn("[WARN]" + msg, val);
            return val;
          }'';
    tail = "list=>list.slice(1)";
    isPath = ''
      e=>{
            console.warn("Paths are not supported in js target. assuming not path", e);
            return false;
          }'';
    substring = ''
      start=>end=>str=>str.substring(start, end)
    '';
    stringLength = "str=>str.length";
    seq = "a=>b=>b";
  };
in
{
  lib.toJS =
    nixExpr:
    let
      inherit (toJS' nixExpr { }) text reifiedFunctions;
    in
    text;
}
