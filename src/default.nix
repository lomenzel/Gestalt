{
  pkgs,
  ...
}:
(rec {
  # sanitize values so they're JSON-serializable (replace functions)
  sanitize = v:
    let lib = pkgs.lib; in
    if lib.isFunction v then "<function>"
    else if lib.isAttrs v then lib.mapAttrs (name: val: sanitize val) v
    else if lib.isList v then lib.map sanitize v
    else v;

  buildGestaltApplication =
    {
      name,
      version,
      modules,
      author,
      target ? targets.ir,
      title ? "Untitled Gestalt Application",
    }@appData:
    import ./buildGestaltApplicatioin.nix {
      inherit pkgs;
      appData = appData // {
        inherit target;
      };
    };

  targets.ir = {
    capabilities.effects = {
      # TODO come up with an idea for how to handle effects
      noop = "Placeholder_nativeEffectReference_NoOp";
      log = x: "Placeholder_nativeEffectReference_Log: ${x.message}";
      
    };
    buildApplication =
      {
        initialState,
        stateType,
        actions,
        name,
        author,
        version,
        functions,
        title,
      }@ir:
      let
        safeIr = sanitize ir;
      in
      if safeIr != ir then pkgs.lib.warn "Warning: The IR contained non-serializable values which have been replaced with placeholders."
        pkgs.writeText "${name}-${version}.json" (builtins.toJSON safeIr)
      else pkgs.writeText "${name}-${version}.json" (builtins.toJSON ir);
  };
  targets.cli = import ./targets/cli/default.nix pkgs;
  toRawIR = import ./toRawIR.nix pkgs;
  targets.web = import ./targets/web/default.nix pkgs;
})
// (import ./types/helpers.nix pkgs)
