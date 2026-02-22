{ pkgs, lib, ... }:
{
  gestaltPlatform.targets.cli = {

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
      }@ir:
      pkgs.callPackage ./default.nix { inherit ir; };
  };
}
