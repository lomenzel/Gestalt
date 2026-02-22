{lib, pkgs, ...}: {
  imports = [
    ./toCpp.nix
  ];
  lib.cppTypeDef = builtins.readFile ./GestaltNixValue.hpp;
}