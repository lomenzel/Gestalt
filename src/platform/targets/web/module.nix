{ pkgs, lib, ... }:
{

  gestaltPlatform.targets.web = {

    capabilities = import ../../defaultCapabilities.nix;
    # backreference to use in upstream compat mode
    name = "web";

    buildApplication =
      {
        initialState,
        actions,
        view,
        name,
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
