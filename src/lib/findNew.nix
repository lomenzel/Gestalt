{ lib, ... }:
let
  findNewAttrName' =
    i: prefix: attrs:
    let
      attrName = "${prefix}${toString i}";
    in
    if builtins.hasAttr attrName attrs then findNewAttrName' (i + 1) prefix attrs else attrName;

in
{
  lib = rec {
    findNewAttrName = findNewAttrName' 0;
    findNewFunctionName = findNewAttrName "__gestalt_func_";
  };
}
