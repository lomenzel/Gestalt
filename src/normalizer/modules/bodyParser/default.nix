{ config, lib, ... }:
{
  imports = [ ./parsers.nix ];
  options = {
    parseBody = lib.mkOption {
      type = lib.types.anything;
      description = "Function that parses the body of functions, handling helper functions and variable references.";
    };
    bodyParsers = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      description = "A set of body parsers for different expression types.";
    };

  };
  config =
    let
      inherit (config) parseBody;
    in
    {
      parseBody =
        rawBody: scopes:

        if
          builtins.elem (builtins.typeOf rawBody) [
            "int"
            "string"
            "bool"
            "float"
            "null"
            "path"
          ]
        then
          {
            helperFunctions = { };
            body = rawBody;
          }
        else if builtins.typeOf rawBody == "list" then

          let
            recCall = builtins.map (e: parseBody e scopes) rawBody;
          in
          {
            helperFunctions = builtins.foldl' (acc: curr: acc // curr.helperFunctions) { } recCall;
            body = builtins.map (e: e.body) recCall;
          }

        else if
          builtins.typeOf rawBody == "set"
          && (
            !builtins.hasAttr "_expr" rawBody
            || rawBody._expr == "lambdaRef"
            || rawBody._expr == "if"
            || rawBody._expr == "primop"
            || rawBody._expr == "concatString/addition"
            || rawBody._expr == "select"
            || rawBody._expr == "attrName"
            || rawBody._expr == "update"
            || rawBody._expr == "concatLists"
            || rawBody._expr == "not"
            || rawBody._expr == "equals"
            || rawBody._expr == "and"
          )
        then

          let
            parsedFields = lib.mapAttrs (
              name: field:
              let
                parsedField = parseBody field scopes;
              in
              {
                helperFunctions = parsedField.helperFunctions;
                body = parsedField.body;
              }
            ) rawBody;
          in
          {
            body = lib.mapAttrs (n: f: f.body) parsedFields;
            helperFunctions = builtins.foldl' (acc: curr: acc // curr.value.helperFunctions) { } (
              lib.attrsToList parsedFields
            );
          }
        else
          config.bodyParsers.${rawBody._expr} rawBody scopes;
    };
}
