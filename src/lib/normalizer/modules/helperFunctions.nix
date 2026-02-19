{ lib, config, ... }:
{
  options = {
    parseVariableSubstitution = lib.mkOption {
      type = lib.types.anything;
      description = "Function that parses variable substitution in function arguments.";
    };
  };

  config = {
    parseVariableSubstitution =
      arguments:
      let
        id =
          if arguments.identifier != null then
            {
              ${arguments.identifier} = {
                _expr = "param";
              };
            }
          else
            { };
        formals =
          builtins.map (e: {
            name = e.name;
            value = {
              _expr = "param";
              field = [ e.name ];
            }
            // (
              if e.defaultExpr or null != null then
                {
                  default = e.defaultExpr;
                }
              else
                { }
            );
          }) arguments.formals or [ ]
          |> lib.listToAttrs;
      in
      (id // formals);
  };
}
