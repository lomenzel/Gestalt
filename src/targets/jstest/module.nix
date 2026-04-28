let
  inherit (import ../../lib/viewSchema.nix) mkOpt types;

  sectionType = types.submodule {
    options = {
      content = mkOpt { type = types.raw; };
      order = mkOpt {
        type = types.nullOr types.int;
        default = null;
      };
    };
  };
in
{
  view =
    { config, ... }:
    {
      options = {
        page = {
          sections = mkOpt { type = types.attrsOf sectionType; };
          title = mkOpt {
            type = types.str;
            default = "Untitled Page";
          };
        };
        componentTree = mkOpt {
          type = types.raw;
          readOnly = true;
          default = builtins.concatStringsSep "\n" (builtins.attrNames config.page.sections);
        };
      };
    };
}
