{pkgs, lib, ...}: {
  gestaltPlatform.targets.tui = {
    capabilities = import ./capabilities.nix;

    # backreference to use in upstream compat mode
    name = "tui";
    buildApplication =
      {
        initialState,
        actions,
        name,
        view,
        author,
        version,
        title,
        unitTests,
        showcaseState,
        ...
      }@ir:
      pkgs.callPackage ./default.nix { inherit ir; };
  };
}