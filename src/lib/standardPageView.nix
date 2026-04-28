# Standard "page with ordered sections" view module shared by GUI targets
# (kirigami, web). Lib-free so it stays cheap to reify via wechselbalg.
let
  inherit (import ./viewSchema.nix) mkOpt types;

  # Stable insertion sort for very small lists (a page has a handful of
  # sections). Avoids depending on `lib.sort`.
  sortBy =
    cmp: xs:
    let
      insert =
        x: ys:
        if ys == [ ] then
          [ x ]
        else if cmp x (builtins.head ys) then
          [ x ] ++ ys
        else
          [ (builtins.head ys) ] ++ insert x (builtins.tail ys);
    in
    builtins.foldl' (acc: x: insert x acc) [ ] xs;

  sectionType = types.submodule {
    options = {
      content = mkOpt { type = types.raw; };
      order = mkOpt {
        type = types.nullOr types.int;
        default = null;
      };
    };
  };

  orderCmp =
    a: b:
    if a.order != null && b.order != null then
      a.order < b.order
    else if a.order != null then
      true
    else if b.order != null then
      false
    else
      a.name < b.name;
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
          default = {
            title = config.page.title;
            sections =
              let
                names = builtins.attrNames config.page.sections;
                sectionsList = map (name: {
                  inherit name;
                  inherit (config.page.sections.${name}) content order;
                }) names;
              in
              sortBy orderCmp sectionsList;
          };
        };
      };
    };
}
