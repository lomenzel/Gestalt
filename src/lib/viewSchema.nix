# Lib-free option / type helpers used by view modules.
#
# These produce plain attrset records that `fastEvalModules` understands.
# Using these (rather than `lib.mkOption` / `lib.types.*`) keeps view modules
# free of the lib closure that wechselbalg would otherwise have to reify.
let
  mkOpt = attrs: attrs // { _type = "option"; };

  types = rec {
    raw = {
      name = "raw";
    };
    str = {
      name = "str";
    };
    int = {
      name = "int";
    };
    bool = {
      name = "bool";
    };
    attrs = {
      name = "attrs";
    };

    nullOr = elemType: {
      name = "nullOr";
      nestedTypes.elemType = elemType;
    };
    listOf = elemType: {
      name = "listOf";
      nestedTypes.elemType = elemType;
    };
    attrsOf = elemType: {
      name = "attrsOf";
      nestedTypes.elemType = elemType;
    };
    submodule = mod: {
      name = "submodule";
      getSubModules = [ mod ];
    };
  };
in
{
  inherit mkOpt types;
}
