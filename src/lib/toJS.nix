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
        evaluationResult = builtins.trace "Evaluating AST" config.lib.evaluateAST ast;
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
                  lib.concatMapStringsSep "\n" (formal: ''
                    const ${formal.name} = __gestalt_param.${formal.name};
                  '') ast.value.arguments.formals
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
        if ast.value == "lessThan" then
          {
            text = ''
              ((a) => (b) => (a < b))
            '';
            inherit reifiedFunctions;
          }
        else if ast.value == "sub" then
          {
            text = ''
              ((a) => (b) => (a - b))
            '';
            inherit reifiedFunctions;
          }
        else if ast.value == "elemAt" then
          {
            text = ''
              ((list)=>(index)=>{
                if (list.length < index)
                  throw new Error("index out of bounds");
                if (typeof index !== "number")
                  throw new Error("index has to be a number");
                return list.at(index);
              })
            '';
            inherit reifiedFunctions;
          }
        else if ast.value == "filter" then
          {
            text = ''
              ((func)=>(list)=>list.filter(func))
            '';
            inherit reifiedFunctions;
          }
        else if ast.value == "all" then
          {
            text = "((func)=>(list)=>list.every(func))";
            inherit reifiedFunctions;
          }
        else if ast.value == "elem" then
          {
            text = ''
              ((item)=>(list)=>{
               return list.some((${jsEquals}(item)))
              })
            '';
            inherit reifiedFunctions;
          }
        else if ast.value == "concatMap" then
          {
            text = ''
              ((func)=>(list)=>{
                const result = [];
                for (let i = 0; i < list.length; i++) {
                  const sublist = func(list[i]);
                  for (let j = 0; j < sublist.length; j++) {
                    result.push(sublist[j]);
                  }
                }
                return result;
              })
            '';
            inherit reifiedFunctions;
          }
        else if ast.value == "map" then
          {
            text = ''
              ((func)=>(list)=>list.map(func))
            '';
            inherit reifiedFunctions;
          }
        else if ast.value == "genList" then
          {
            text = ''
              ((func)=>(count)=>{
              const result = [];
              for (let i = 0; i < count; i++) {
                result.push(func(i));
              } 
              return result; 
              })
            '';
            inherit reifiedFunctions;
          }
        else if ast.value == "foldl'" then
          {
            text = ''
              ((op)=>(acc)=>(list)=>list.reduce((acc, curr)=>op(acc)(curr), acc))
            '';
            inherit reifiedFunctions;
          }
        else if ast.value == "typeOf" then
          {
            text = ''
              ((e)=>{
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

                throw new Error("Unsupported type " + t);  
              })
            '';
            inherit reifiedFunctions;
          }
        else if ast.value == "toString" then
          {
            text = ''
              ((e)=>{
                if (e === null)
                  return "";
                return e.toString()
              })
            '';
            inherit reifiedFunctions;
          }
        else if ast.value == "length" then
          {
            text = "((e)=>e.length)";
            inherit reifiedFunctions;
          }
        else if ast.value == "mul" then
          {
            text = "((a)=>(b)=>(a * b))";
            inherit reifiedFunctions;
          }
        else if ast.value == "div" then
          {
            text = "((a)=>(b)=>(a / b))";
            inherit reifiedFunctions;
          }
        else if ast.value == "hasAttr" then 
          {
            text = "((attr)=>(s)=>Object.prototype.hasOwnProperty(s, attr)";
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
        {
          text = ''
            ((${(ASTtoJS ast.value.expression reifiedFunctions).text}).${
              lib.concatStringsSep "." (
                builtins.map (
                  e: if e._expr == "attrName" then e.value else throw "dynamic select maybe? "
                ) ast.value.path
              )
            })
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
      else if ast._expr == "notEquals" then
        {

          text = ''
            (!(${jsEquals}(${(ASTtoJS ast.value.e1 reifiedFunctions).text})(${(ASTtoJS ast.value.e2 reifiedFunctions).text})))
          '';
          inherit reifiedFunctions;

        }

      else
        throw "Unsupported AST node in ASTtoJS: ${ast._expr}";
in

{
  lib.toJS =
    nixExpr:
    let
      inherit (toJS' nixExpr { }) text reifiedFunctions;
    in
    builtins.replaceStrings [ "\n" ] [ "" ] text;

}
