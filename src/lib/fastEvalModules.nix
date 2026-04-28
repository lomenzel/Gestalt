# Lib-free, fast `evalModules` substitute used in the per-state view path.
#
# Why: the `view` function is reified by wechselbalg (so the IR can be
# translated to JS / C++). When the body uses `lib.evalModules`, the walker
# has to reify all of nixpkgs' module system — which is huge, slow, and in
# practice blows the stack. We only need a small subset of evalModules:
# enough to merge the view sub-modules and assemble `componentTree`.
#
# Supported subset:
#   * Modules as functions or attrsets, with implicit `config` (no `_module`,
#     no `imports`, no `disabledModules`).
#   * Options declared as `{ _type = "option"; … }` records (compatible with
#     `lib.mkOption`).
#   * Types `raw`, `str`, `int`, `bool`, `attrs`, `nullOr`, `listOf`,
#     `attrsOf`, `submodule`, `submoduleWith` (recognised by `type.name`).
#   * `default`, `readOnly` on options.
#   * Recursive `config` reference inside default values (Nix laziness).
#   * `specialArgs` passed to module functions.
#
# Unsupported (and not needed for the view path):
#   * `mkDefault`/`mkForce`/`mkOverride` priority handling — last definition
#     wins.
#   * `mkIf`, `mkMerge` — values are taken as-is.
#   * Option `apply`, `check`, `merge` — types are dispatched by `name` only.
let
  isOption = x: builtins.isAttrs x && (x._type or "") == "option";

  # Walk a path inside an attrset; return null if missing.
  walkPath =
    path: a:
    if path == [ ] then
      a
    else if !(builtins.isAttrs a) then
      null
    else if !(builtins.hasAttr (builtins.head path) a) then
      null
    else
      walkPath (builtins.tail path) a.${builtins.head path};

  # Recursively merge nested option-declaration trees coming from multiple
  # modules. Option leaves: later definition wins.
  mergeOpts =
    a: b:
    if isOption a || isOption b then
      b
    else if builtins.isAttrs a && builtins.isAttrs b then
      let
        extra = builtins.filter (k: !(builtins.hasAttr k a)) (builtins.attrNames b);
        keys = builtins.attrNames a ++ extra;
      in
      builtins.listToAttrs (
        map (k: {
          name = k;
          value =
            if builtins.hasAttr k a && builtins.hasAttr k b then
              mergeOpts a.${k} b.${k}
            else if builtins.hasAttr k a then
              a.${k}
            else
              b.${k};
        }) keys
      )
    else
      b;

  fastEvalModules =
    {
      modules,
      specialArgs ? { },
    }:
    let
      apply = m: if builtins.isFunction m then m ({ inherit config; } // specialArgs) else m;
      modOuts = map apply modules;

      collectedOptions = builtins.foldl' mergeOpts { } (map (m: m.options or { }) modOuts);

      # Definitions for the option at `path`, gathered from all module outputs.
      # A module may put values directly at top level, or under `config = {…}`.
      getDefs =
        path:
        let
          fromMod =
            m:
            let
              direct = walkPath path (
                removeAttrs m [
                  "options"
                  "imports"
                  "config"
                ]
              );
              underCfg = walkPath path (m.config or { });
            in
            if direct != null then direct else underCfg;
        in
        builtins.filter (x: x != null) (map fromMod modOuts);

      buildConfig =
        opts: path:
        builtins.mapAttrs (
          name: opt:
          let
            p = path ++ [ name ];
          in
          if isOption opt then evalOption opt p else buildConfig opt p
        ) opts;

      evalOption =
        opt: path:
        let
          defs = getDefs path;
        in
        if opt.readOnly or false then
          opt.default
            or (throw "fastEvalModules: readOnly option ‘${builtins.concatStringsSep "." path}’ has no default")
        else if defs == [ ] then
          if opt ? default then
            opt.default
          else
            throw "fastEvalModules: missing definition for option ‘${builtins.concatStringsSep "." path}’"
        else
          evalType (opt.type or { name = "raw"; }) defs;

      evalType =
        t: defs:
        let
          n = t.name or "raw";
        in
        if n == "submodule" || n == "submoduleWith" then
          (fastEvalModules {
            modules = (t.getSubModules or [ ]) ++ defs;
            inherit specialArgs;
          }).config
        else if n == "attrsOf" then
          let
            inner = t.nestedTypes.elemType;
            merged = builtins.foldl' (a: b: a // b) { } defs;
          in
          builtins.mapAttrs (_: v: evalType inner [ v ]) merged
        else if n == "listOf" then
          let
            inner = t.nestedTypes.elemType;
            concat = builtins.concatLists defs;
          in
          map (v: evalType inner [ v ]) concat
        else if n == "nullOr" then
          let
            last = builtins.elemAt defs (builtins.length defs - 1);
          in
          if last == null then null else evalType t.nestedTypes.elemType [ last ]
        else
          # raw / str / int / bool / attrs / unknown: take the last definition.
          builtins.elemAt defs (builtins.length defs - 1);

      config = buildConfig collectedOptions [ ];
    in
    {
      inherit config;
    };
in
fastEvalModules
