{ pkgs, ... }:
let
  lib = pkgs.lib;
  allTests =
    lib.filesystem.listFilesRecursive ./.
    |> lib.filter (path: lib.hasSuffix ".test.nix" path)
    |> lib.map (
      path:
      let
        test = import path;
        testModule =
          if builtins.typeOf test == "list" then
            [ { tests.unit = test; } ]
          else
            [ { tests.unit = [ test ]; } ];

      in
      [
        (lib.gestaltCore.js (
          lib.mkGestaltIR {
            target = pkgs.gestaltPlatform.targets.web;
            modules = testModule;
          }
        ))
        (lib.gestaltCore.cpp (
          lib.mkGestaltIR {
            target = pkgs.gestaltPlatform.targets.tui;
            modules = testModule;
          }
        ))
      ]
    )
    |> lib.flatten
    |> lib.concatStringsSep " ";
in
pkgs.stdenv.mkDerivation {
  name = "gestalt-tests";

  dontUnpack = true;
  installPhase = ''
    echo "executed tests: ${allTests}" > $out
  '';
}
