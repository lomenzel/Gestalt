{ pkgs, lib, ... }:
{
  gestaltPlatform.targets.cli = {

    # backreference to use in upstream compat mode
    name = "cli";

    capabilities = import ./capabilities.nix;
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
      }@ir:
      pkgs.callPackage ./default.nix { inherit ir; };
  };
}
