pkgs: function: param_type: types: functions:

/*
  Type = {
      _type: "struct";
      fields: {
        field: Type
        field2: Type
      };
    }
    | { # attr sets. Keys are always strings.
      _type: "map";
      type: Type;
    }
    | { _type: list; type: Type; 
    maybe future optimization:
    canBeEmpty: (true| false) 
    }
    | { _type: exception | string | bool}
    | { _type: union; types: [ Type ] }
    | { _type: typeRef; name: string }
    | { _type: never}
    | { _type: int | float; 

    maybe future optimization:
    canBeZero: (true | false)
    }

  ExampleTypes = {
    type_a = {
      _type = "struct";
      fields = {
        field1 = { _type = "int"; canBeZero = true;};
        field2 = {
          _type = "list";
          type = {
            _type = "typeRef";
            name = "type_a";
          };
          canBeEmpty = true;
        };
      }
    }
*/

let
  _typeOf =
    expr: types: functions
    if
      builtins.elem builtins.typeOf expr [
        "int"
        "string"
        "bool"
        "float"
      ]
    then
      {
        type = {
          _type = builtins.typeOf expr;
        };
        inherit types;
      }
    else if builtins.typeOf expr == "list" then
      if builtins.length expr == 0 then
        {
          type = {
            _type = "list";
            type = {
              _type = "never";
            };
            canBeEmpty = true;
          };
          inherit types;
        }
      else
        let
          itemTypes = pkgs.lib.unique (
            builtins.foldl'
              (
                acc: item:
                let
                  itemTypeInfo = _typeOf item acc.types;
                in
                {
                  types = acc.types // itemTypeInfo.types;
                  elemTypes = acc.elemTypes ++ [ itemTypeInfo.type ];
                }
              )
              {
                inherit types;
                elemTypes = [ ];
              }
              expr
          );
          unifiedType =
            pkgs.lib.foldl'
              (acc: itemTypeList: {
                _type = "union";
                types = pkgs.lib.unique (acc.types ++ itemTypeList);
              })
              {
                _type = "union";
                types = [ ];
              }
              itemTypes;
        in
        [
          {
            _type = "list";
            type = unifiedType;
            canBeEmpty = false;
          }
        ]

    else if builtins.typeOf expr == "set" && !builtins.hasAttr "_expr" then
      let
        newType = findNewTypeName types 0;
        recCall =
          builtins.foldl'
            (
              acc: curr:
              let
                r = typeOf curr.value acc.types;
              in
              {
                types = r.types;
                fields = acc.fields ++ [
                  {
                    inherit (curr) name;
                    value = r.type;
                  }
                ];
              }

            )
            {
              types = types // {
                ${newType} = "_temp";
              };
              fields = [ ];
            }
            pkgs.lib.attrsToList;
      in

      {
        types =
          types
          // recCall.types
          // {
            ${newType} = {
              _type = "struct";
              fields = pkgs.lib.listToAttrs (recCall.fields);
            };
          };
        fields = recCall.fields;
      }

    else
      throw "unsupported return type: " + builtins.typeOf function.body + (builtins.toJSON function.body);

  findNewTypeName =
    types: i:
    if builtins.hasAttr ("type_" + builtins.toString i) types then
      findNewTypeName types (i + 1)
    else
      "type_" + builtins.toString i;

in
typeOf function.body
