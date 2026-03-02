{
  stdenv,
  ir,
  curl,
  nlohmann_json,
  runCommand,
  ansilove,
  lib,
  buildPackages,
}:
let
  libgestalt = lib.gestaltCore.cpp ir;
in
stdenv.mkDerivation (finalAttrs: {
  pname = ir.name;
  version = ir.version;
  src = ./src;
  buildInputs = [
    libgestalt
    curl
    nlohmann_json
  ];
  buildPhase = ''
    $CXX -O3 -flto -I ${libgestalt}/include -I ${nlohmann_json}/include main.cpp -o main ${libgestalt}/lib/libgestalt.a -lcurl
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp ./main $out/bin/${ir.name}
  '';
  meta = {
    platforms = lib.platforms.unix;
  };
  passthru = {
    inherit libgestalt;
    screenshot =
      runCommand "${ir.name}.png"
        {
          nativeBuildInputs = [ ansilove ];
        }
        ''
          mkdir -p $out
          echo "0" | ${stdenv.hostPlatform.emulator buildPackages} ${finalAttrs.finalPackage}/bin/${ir.name} > capture.ansi

          ansilove capture.ansi -o $out/screenshot.png

        '';
  };
})
