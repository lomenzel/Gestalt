{
  pkgs,
  nix,
  nixpkgs,
}:
{
  name,
  version,
  targetName,
  src,
}:

let
  flake = pkgs.writeTextDir "flake.nix" ''
    {
    inputs = {
      nixpkgs.url = "path:${nixpkgs}";
      gestalt.url = "path:${./../../.}";

    };
    outputs = {nixpkgs, self, gestalt, ...}@inputs: {
      packages.default."${pkgs.system}" = gestalt.lib."${pkgs.system}".buildGestaltApplication {
        name = "${name}";
        version = "${version}";
        target = gestalt.lib."${pkgs.system}".targets.${targetName};
        modules = [
          import ${./.}/default.nix;
        ];
    };
    }
  '';

in
pkgs.stdenv.mkDerivation {
  pname = name;
  inherit version src;

  buildInputs = [ flake ];

  buildPhase = ''
    echo $(${nix}/bin/nix build ${flake}\#default.${pkgs.system} --no-registries --no-update-lock-file --no-write-lock-file --extra-experimental-features 'flakes pipe-operators recursive-nix nix-command')
    ls -lah
    ls -lah result/
    exit 1
  '';
  installPhase = ''
    if [ -d "$(readlink -f result)" ]; then
      mkdir -p $out
      cp -r "$(readlink -f result)"/* "$out/"
    else
      cp "$(readlink -f result)" "$out"
    fi
  '';

  requiredSystemFeatures = [ "recursive-nix" ];

}
