pkgs:
let

  findNewFunctionName = functions: findNewAttrName functions "f" 0;

  findNewTypeName = types: findNewAttrName types "T" 0;

  findNewAttrName =
    attrs: prefix: i:
    let
      attrName = "${prefix}${toString i}";
    in
    if builtins.hasAttr attrName attrs then findNewAttrName attrs prefix (i + 1) else attrName;

  splitType =
    types: type:
    if type == null then
      {
        inherit types;
        type = null;
      }
    else
    assert
      builtins.typeOf type == "set"
      && builtins.hasAttr "_type" type
      && builtins.all (
        { name, value }: builtins.typeOf value == "set" && builtins.hasAttr "_type" value
      ) (pkgs.lib.attrsToList types);
    let
      existingType = pkgs.lib.findFirst ({ value, ... }: value == type) null (pkgs.lib.attrsToList types);
    in
    (
      if existingType != null then
        {
          inherit types;
          type = {
            _type = "typeRef";
            name = existingType.name;
          };
        }
      else if
        builtins.elem type._type [
          "int"
          "float"
          "string"
          "bool"
          "null"
        ]
      then
        let
          typeName = findNewTypeName types;
        in
        {
          types = types // {
            ${typeName} = type;
          };
          type = {
            _type = "typeRef";
            name = typeName;
          };
        }
      else if type._type == "typeRef" then
        if builtins.hasAttr type.name types then
          {
            inherit types;
            type = type;
          }
        else
          throw "Type reference to unknown type ${type.name}"
      else if type._type == "struct" then
        let
          foldRes =
            builtins.foldl'
              (
                acc: curr:

                (
                  let
                    recCall = splitType acc.types curr.value;
                  in
                  {
                    types = recCall.types;
                    fields = acc.fields // {
                      ${curr.name} = recCall.type;
                    };
                  }
                )
              )
              {
                inherit types;
                fields = { };
              }
              (pkgs.lib.attrsToList type.fields);

          newTypeName = findNewTypeName foldRes.types;
          newType = {
            _type = "struct";
            fields = foldRes.fields;
          };

          existingType = pkgs.lib.findFirst ({ value, ... }: value == newType) null (
            pkgs.lib.attrsToList foldRes.types
          );
        in
        if existingType != null then
          {
            types = foldRes.types;
            type = {
              _type = "typeRef";
              name = existingType.name;
            };
          }
        else
          {
            types = foldRes.types // {
              ${newTypeName} = newType;
            };
            type = {
              _type = "typeRef";
              name = newTypeName;
            };
          }

      else if type._type == "enum" then
        let
          newTypeName = findNewTypeName types;
        in
        {
          types = types // {
            ${newTypeName} = type;
          };
          type = {
            _type = "typeRef";
            name = newTypeName;
          };
        }
      else if type._type == "list" then
        let
          recCall = splitType types type.type;
          newTypeName = findNewTypeName recCall.types;
          newType = {
            _type = "list";
            type = recCall.type;
          };
        in
        {
          types = recCall.types // {
            ${newTypeName} = newType;
          };
          type = {
            _type = "typeRef";
            name = newTypeName;
          };
        }
      else if type._type == "map" then
        let
          recCall = splitType types type.type;
          newTypeName = findNewTypeName recCall.types;
          newType = {
            _type = "map";
            type = recCall.type;
          };
        in
        throw "map types are not supported yet."
      # {
      #   types = recCall.types // {
      #     ${newTypeName} = newType;
      #   };
      #   type = {
      #     _type = "typeRef";
      #     name = newTypeName;
      #   };
      # }
      else if type._type == "union" then
        let
          foldRes =
            builtins.foldl'
              (
                acc: value:
                let
                  recCall = splitType acc.types value;
                in
                {
                  types = recCall.types;
                  unionTypes = acc.unionTypes ++ [ recCall.type ];
                }
              )
              {
                inherit types;
                unionTypes = [ ];
              }
              type.types;

          newTypeName = findNewTypeName foldRes.types;
          newType = {
            _type = "union";
            types = foldRes.unionTypes;
          };
        in
        {
          types = foldRes.types // {
            ${newTypeName} = newType;
          };
          type = {
            _type = "typeRef";
            name = newTypeName;
          };
        }
      else
        throw "Type ${builtins.toJSON type} not supported yet."
    );

  inferType =
    {
      functionName,
      functions,
      inferedFunctions ? { },
      types,
    }@parameters:
    let
      function = functions.${functionName};
    in
    (
      if (builtins.hasAttr functionName inferedFunctions) then
        {
          inherit functions types inferedFunctions;
          allreadyInfered = true;
        }
      else if builtins.hasAttr "paramType" function && builtins.hasAttr "returnType" function then
        let
          spParamType = splitType types function.paramType;
          spReturnType = splitType spParamType.types function.returnType;
          streamlinedFunction = function // {
            paramType = spParamType.type;
            returnType = spReturnType.type;
          };
          expectedReturnType = inferType {
            inherit functionName;
            inherit (spReturnType) types;
            functions = functions // {
              ${functionName} = builtins.removeAttrs streamlinedFunction [ "returnType" ];
            };
          };
        in
        if expectedReturnType.functions.${functionName}.returnType != streamlinedFunction.returnType then # since both are split one after eachother this should be dedupilcated and actually the same if the type is the same (both are a typeRef)
          throw "Inferred return type ${
            builtins.toJSON expectedReturnType.functions.${functionName}.returnType
          } does not match specified return type ${builtins.toJSON streamlinedFunction.returnType} for function ${functionName}. types = ${builtins.toJSON spReturnType.types}"
        else
          expectedReturnType
      else if !builtins.hasAttr "returnType" function && !builtins.hasAttr "paramType" function then
        throw "type inference needs at least returnType or paramType to be specified."
      else if builtins.hasAttr "paramType" function then
        let
          expr_type = inferExprType {
            expr = function.body;
            paramType = function.paramType;
            functions = functions;
            inferedFunctions = inferedFunctions // {
              ${functionName} = true;
            };
            types = types;
          };
        in
        {
          types = expr_type.types;
          functions = expr_type.functions // {
            ${functionName} = function // {
              returnType = expr_type.type;
            };
          };
          inherit inferedFunctions;
        }
      else
        throw "backward type inference is not supported yet."
    );

  inferExprType =
    {
      expr,
      paramType,
      functions,
      inferedFunctions,
      types,
    }:
    if
      builtins.elem (builtins.typeOf expr) [
        "int"
        "null"
        "float"
        "bool"
        "string"
      ]
    then
      let
        spType = splitType types {
          _type = builtins.typeOf expr;
        };
      in
      {
        types = spType.types;
        type = spType.type;
        inherit functions inferedFunctions;
      }
    else if builtins.typeOf expr == "set" && !builtins.hasAttr "_expr" expr then
      let
        t =
          builtins.foldl'
            (
              acc: curr:
              let
                recCall = inferExprType {
                  expr = curr.value;
                  inherit (acc)
                    types
                    functions
                    inferedFunctions
                    paramType
                    ;
                };
              in
              {
                fields = acc.fields // {
                  ${curr.name} = recCall.type;
                };
                inherit (recCall) types functions inferedFunctions;
                inherit paramType;

              }
            )
            {
              fields = { };
              inherit
                types
                functions
                paramType
                inferedFunctions
                ;
            }
            (pkgs.lib.attrsToList expr);
        spType = splitType t.types {
          inherit (t) fields;
          _type = "struct";
        };
      in
      {
        inherit (spType) types type;
        inherit (t) functions inferedFunctions;
      }

    else if builtins.typeOf expr == "list" then
      let
        foldRes =
          builtins.foldl'
            (
              acc: curr:
              let
                recCall = inferExprType {
                  expr = curr;
                  inherit (acc) types functions inferedFunctions;
                };

              in
              if acc.type == null || acc.type == recCall.type then
                {
                  type = recCall.type;
                  types = recCall.types;
                  functions = recCall.functions;

                }
              else
                throw "list with heterogeneous types are not supported yet. Found ${builtins.toJSON acc.type} and ${builtins.toJSON recCall.type}"
            )
            {
              type = null;
              inherit types functions inferedFunctions;
            }
            expr;
        spType = splitType foldRes.types {
          _type = "list";
          type = foldRes.type;
        };

      in
      {
        types = spType.types;
        type = spType.type;
        functions = foldRes.functions // {
          returnType = spType.type;
        };
        inferedFunctions = foldRes.inferedFunctions;
      }

    else if builtins.typeOf expr == "set" && builtins.hasAttr "_expr" expr then
      if expr._expr == "update" then
        let
          baseTypeRes = inferExprType {
            expr = expr.value.e1;
            inherit
              types
              functions
              inferedFunctions
              paramType
              ;
          };
          updateTypeRes = inferExprType {
            expr = expr.value.e2;
            inherit (baseTypeRes) types functions inferedFunctions;
            inherit paramType;
          };
          baseType = followTypeRef baseTypeRes.types baseTypeRes.type;
          updateType = followTypeRef updateTypeRes.types updateTypeRes.type;
        in
        if baseType._type != "struct" then
          throw "can only update struct types, got base expression of type ${builtins.toJSON baseType}"
        else if updateType._type != "struct" then
          throw "can only update with struct types, got update expression of type ${builtins.toJSON updateType}"
        else
          let
            mergedFields = baseType.fields // updateType.fields;
            spType = splitType updateTypeRes.types {
              _type = "struct";
              fields = mergedFields;
            };
          in
          {
            inherit (spType) types type;
            inherit (updateTypeRes) functions inferedFunctions;
          }

      else if expr._expr == "param" then
        let
          f = expr.field or [ ];
          t = builtins.foldl' (
            acc: curr:
            let
              currT = followTypeRef types acc;
            in
            if currT._type != "struct" then
              throw "param field access on non-struct type ${builtins.toJSON currT}"
            else if !builtins.hasAttr curr currT.fields then
              throw "param field access to unknown field ${curr} on type ${builtins.toJSON currT}"
            else
              currT.fields.${curr}
          ) paramType f;
          spType = splitType types t;
        in
        {
          inherit (spType) types type;
          inherit functions inferedFunctions;
        }
      else if expr._expr == "concatString/addition" then
        builtins.trace "inferring type for concatString/addition expression ${builtins.toJSON expr}" (
          let
            foldRes =
              builtins.foldl'
                (
                  acc: curr:
                  let
                    recCall = inferExprType {
                      expr = curr;
                      inherit paramType;
                      inherit (acc) types functions inferedFunctions;
                    };
                    currT = followTypeRef acc.types recCall.type;
                  in
                  if currT == null then
                    {pType = null;
                    inherit (recCall) types functions inferedFunctions;
                    }
                  else if
                    !builtins.elem currT._type [
                      "string"
                      "float"
                      "int"
                    ]
                  then
                    throw "addition or string concatenation wont work on ${builtins.toJSON currT}"
                  else if acc.pType == "not initialized" then
                    {
                      pType = currT;
                      inherit (recCall) types functions inferedFunctions;
                    }
                  else if acc.pType != currT then
                    builtins.throw "cannot add / concat different types: ${builtins.toJSON acc.pType} with ${builtins.toJSON currT}"
                  else
                    {
                      pType = acc.pType;
                      inherit (recCall) types functions inferedFunctions;
                    }
                )
                {
                  pType = "not initialized";
                  inherit types functions inferedFunctions;
                }
                expr.value;

            spType = splitType foldRes.types foldRes.pType;
          in
          {
            inherit (spType) type types;
            inherit (foldRes) functions inferedFunctions;
          }
        )

      else if expr._expr == "select" then
        let
          f = expr.value.path or [ ];
          t = builtins.foldl' (
            acc: curr:
            let
              currT = followTypeRef baseTypeRes.types acc;
            in
            if currT._type != "struct" then
              throw "param field access on non-struct type ${builtins.toJSON currT}"
            else if !builtins.hasAttr curr currT.fields then
              throw "param field access to unknown field ${curr} on type ${builtins.toJSON currT}"
            else
              currT.fields.${curr}
          ) baseTypeRes.type f;
          spType = splitType types t;

          baseTypeRes = inferExprType {
            inherit
              types
              functions
              inferedFunctions
              paramType
              ;
            expr = expr.value.expression;
          };
        in
        {
          inherit (spType) types type;
          inherit functions inferedFunctions;
        }

      else if expr._expr == "call" then
        (
          let
            fName = expr.value.function.value.name;
            f = functions.${fName};
            existingParamType' = if builtins.hasAttr "paramType" f then f.paramType else null;
            argTypesRes =
              builtins.foldl'
                (
                  acc: curr:
                  (
                    let
                      recCall = inferExprType {
                        expr = curr;
                        inherit (acc) functions types inferedFunctions;
                        inherit paramType;
                      };
                    in
                    {
                      ts = acc.ts ++ [ recCall.type ];
                      inherit (recCall) types functions inferedFunctions;
                    }
                  )
                )
                {
                  ts = [ ];
                  inherit types functions inferedFunctions;
                }
                expr.value.args;
            argTypes =
              if builtins.typeOf argTypesRes.ts == "list" && builtins.length argTypesRes.ts == 1 then
                builtins.head argTypesRes.ts |> followTypeRef argTypesRes.types
              else
                argTypesRes.ts |> builtins.map (t: followTypeRef argTypesRes.types t);
            existingParamType =
              if builtins.typeOf existingParamType' == "list" then
                if builtins.length existingParamType' == 1 then
                  followTypeRef types (builtins.head existingParamType')
                else
                  builtins.map (t: followTypeRef types t) existingParamType'
              else if existingParamType' != null then
                followTypeRef types existingParamType'
              #followTypeRef types existingParamType'
              else
                null;
            existingReturnType = if builtins.hasAttr "returnType" f then f.returnType else null;
          in
          if argTypes == existingParamType then
            if existingReturnType != null then
              let
                spReturnType = splitType argTypesRes.types existingReturnType;
              in
              {
                type = spReturnType.type;
                types = spReturnType.types;
                inherit (argTypesRes) functions inferedFunctions;
              }
            else
              {
                type = existingReturnType;
                inherit (argTypesRes) types functions inferedFunctions;
              }

          else if existingParamType == null then
            let
              argTypesSplit = if builtins.typeOf argTypes == "list" then builtins.map (e: (splitType argTypesRes.types e).type) argTypes
              else (splitType argTypesRes.types argTypes).type;

              funWithSetArgTypes = f // {
                # splitTypes
                paramType = argTypesSplit;
              };
              recCallInferType = inferType {
                functionName = fName;
                functions = argTypesRes.functions // {
                  ${fName} = funWithSetArgTypes;
                };
                inherit (argTypesRes) types inferedFunctions;
              };
            in
            {
              type = recCallInferType.functions.${fName}.returnType;
              inherit (recCallInferType) functions types inferedFunctions;
            }

          else
            # todo rewrite the expr to use a new function id and duplicate the old function with new param types
            throw ''unsupported case in call expression type inference (this has to be the case where the function once got infered with different argument types. so we need to duplicate this function in IR. if you encounter this error, please file a bug report) ${builtins.toJSON expr}
            
            existing param type: ${builtins.toJSON existingParamType}
            argument types: ${builtins.toJSON argTypes}
            ''
        )
      else if expr._expr == "if" then
        let
          conditionTypeRes = inferExprType {
            expr = expr.value.condition;
            inherit
              types
              functions
              inferedFunctions
              paramType
              ;
          };
          thenTypeRes = inferExprType {
            expr = expr.value.${"then"};
            inherit (conditionTypeRes)
              types
              functions
              inferedFunctions
              ;
            inherit paramType;
          };
          elseTypeRes = inferExprType {
            expr = expr.value.${"else"};
            inherit (thenTypeRes)
              types
              functions
              inferedFunctions
              ;
            inherit paramType;
          };
          conditionType = followTypeRef newTypes conditionTypeRes.type;
          thenType = followTypeRef newTypes thenTypeRes.type;
          elseType = followTypeRef newTypes elseTypeRes.type;

          newTypes = elseTypeRes.types;
        in
        if conditionType._type != "bool" then
          throw "condition of if expression must be a boolean or evaluate at runtime to a boolean but it is of type ${builtins.toJSON conditionType}"
        else if thenType != elseType then
          if thenType == null then
            elseTypeRes
          else if elseType == null then
            let
              spType = splitType newTypes thenType;
              in
            {
              inherit (spType) type types;
              inherit (elseTypeRes)  functions inferedFunctions;
            }
          else
            throw "if expressions must return the same type in both branches ${expr} #### returns ${builtins.toJSON thenType} #### in one branch and ${builtins.toJSON elseType} in the other"
        else
          elseTypeRes

      else if expr._expr == "primop" then
        if expr.value == "lessThan" then
          if builtins.typeOf paramType != "list" || builtins.length paramType != 2 then
            throw "for primop ${expr.value} the parameters must be a list of two same number values but it is ${builtins.toJSON paramType}"
          else
            let
              firstType = followTypeRef types (builtins.head paramType);
              secondType = followTypeRef types (builtins.head (builtins.tail paramType));
            in
            if firstType != secondType then
              throw "less then must be called with the same argument type but its called with ${builtins.toJSON firstType} and ${builtins.toJSON secondType}"
            else if
              !builtins.elem secondType._type [
                "int"
                "float"
              ]
            then
              throw "less then is only supported with ints and floats. but got ${builtins.toJSON secondType}"
            else
              let
                boolTypeRes = splitType types { _type = "bool"; };
              in
              {
                inherit (boolTypeRes) types type;
                inherit inferedFunctions functions;
              }
        else if
          builtins.elem expr.value [
            "sub"
            "mul"
            "div"
          ]
        then
          if builtins.typeOf paramType != "list" || builtins.length paramType != 2 then
            throw "for primop ${expr.value} the parameters must be a list of two same number values but it is ${builtins.toJSON paramType}"
          else
            let
              firstType = followTypeRef types (builtins.head paramType);
              secondType = followTypeRef types (builtins.head (builtins.tail paramType));
            in
            if firstType != secondType then
              throw "${expr.value}  must be called with the same argument type but its called with ${builtins.toJSON firstType} and ${builtins.toJSON secondType}"
            else if
              !builtins.elem secondType._type [
                "int"
                "float"
              ]
            then
              throw "${expr.value} is only supported with ints and floats. but got ${builtins.toJSON secondType}"
            else
              let
                typeRes = splitType types secondType;
              in
              {
                inherit (typeRes) type types;
                inherit functions inferedFunctions;
              }
        else
          throw "primop ${expr.value} not supported yet"

      else
        throw "expression type inference not implemented for set ${expr._expr} expression ${builtins.toJSON expr}"

    else
      throw "expression type inference not implemented for ${builtins.toJSON expr}";

  followTypeRef =
    types: type:
    if type != null && type._type == "typeRef" then
      if builtins.hasAttr type.name types then
        followTypeRef types types.${type.name}
      else
        throw "Type reference to unknown type ${type.name}"
    else
      type;

in
{
  inherit splitType inferType;
}
