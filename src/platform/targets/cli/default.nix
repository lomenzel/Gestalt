{ stdenv, lib, nodejs, makeWrapper, ir, writeText }:
stdenv.mkDerivation {
  pname = ir.name;
  inherit (ir) version;
  src = null;
  nativeBuildInputs = [ makeWrapper ];
  dontUnpack = true;
  dontPatch = true;
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/lib/generated
    cp ${lib.gestaltCore.js ir} $out/lib/generated/core.js
    cp ${./main.js} $out/lib/main.js
    makeWrapper ${nodejs}/bin/node $out/bin/${ir.name} \
      --add-flags "$out/lib/main.js"
  '';

  meta = {
    platforms = lib.platforms.unix;
  };
}
