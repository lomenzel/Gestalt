{ lib, ... }:
{
  view =
    { config, ... }:
    {
      options = {
        page = {
          sections = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule {
                options.content = lib.mkOption {
                  type = lib.types.raw;
                };
                options.order = lib.mkOption {
                  type = lib.types.nullOr lib.types.int;
                  default = null;
                };
              }
            );
          };
          title = lib.mkOption {
            type = lib.types.str;
            default = "Untitled Page";
          };
        };
        componentTree = lib.mkOption {
          type = lib.types.raw;
          readOnly = true;
          default = {
            title = config.page.title;
            sections =
              let
                sectionsList = lib.mapAttrsToList (name: section: {
                  inherit name;
                  inherit (section) content order;
                }) config.page.sections;
                sorted = lib.sort (
                  a: b:
                  if a.order != null && b.order != null then
                    a.order < b.order
                  else if a.order != null then
                    true
                  else if b.order != null then
                    false
                  else
                    a.name < b.name
                ) sectionsList;
              in
              sorted;
          };
        };
      };
    };
}
