{ lib, ... }:
{
  view = {config,...}: {
    options = {
      page = {
        sections = lib.mkOption {
          type = #lib.types.raw;
             lib.types.attrsOf (
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
        type =  lib.types.raw;
        readOnly = true;
        default = "${lib.concatStringsSep "\n" ((lib.attrNames config.page.sections))}";
      };
    };
    
  };
}
