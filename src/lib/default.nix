{
  pkgs,
  nix,
  nixpkgs,
  ...
}:
(rec {
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

  buildGestaltApplicationFromSourceDir = import ./upstreamNixCompatibilityWrapper.nix {
    inherit pkgs nix nixpkgs;
  };

  targets.ir = {
    effects = {
      # TODO come up with an idea for how to handle effects
      noop = "Placeholder_nativeEffectReference_NoOp";
    };
    buildApplication =
      {
        initialState,
        stateType,
        actions,
        types,
        name,
        author,
        version,
        functions,
        title,
      }@ir:
      pkgs.writeText "${name}-${version}.json" (builtins.toJSON ir);
  };
  targets.cli = import ./targets/cli/default.nix pkgs;
  toRawIR = import ./toRawIR.nix pkgs;
})
// (import ./types/helpers.nix pkgs)
