{
  src,
  nix,
  nixpkgs,
  pkgs,
  gestaltSrc
}:

let

  nestedFile = pkgs.writeText "nested.nix" ''
    let
      pkgs = import <nixpkgs> {};
      lib = import ${gestaltSrc}/src/lib {inherit pkgs;};
      appData = import "${src}/default.nix" ;
    in
    lib.buildGestaltApplication (appData // {
      target = lib.targets.cli;
    })
  '';

  appData = import "${src}/default.nix";
in

pkgs.stdenv.mkDerivation {
  pname = "test";
  version = "2";

  buildInputs = [
    nix
  ];

  inherit null;
  unpackPhase = "true";
  installPhase = ''
    export NIX_PATH="nixpkgs=${nixpkgs}";
    ${nix}/bin/nix-build ${nestedFile} --extra-experimental-features 'pipe-operators'
    ls -lah

    mkdir -p $out
    cp -r ./result/* $out/
    
  '';

  requiredSystemFeatures = [ "recursive-nix" ];

}
