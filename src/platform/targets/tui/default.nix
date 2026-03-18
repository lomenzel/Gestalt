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

  package = stdenv.mkDerivation (finalAttrs: {
    pname = ir.name;
    version = ir.version;
    src = ./src;
    buildInputs = [
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
    passthru = {
      inherit libgestalt;
    };
    meta = {
      #platforms = lib.platforms.unix;
    };

  });
in

package.overrideAttrs (old: {
  passthru = old.passthru // {
    screenshot =
      runCommand "${ir.name}.png"
        {
          nativeBuildInputs = [ ansilove ];
        }
        ''
          mkdir -p $out
          echo "0" | ${stdenv.hostPlatform.emulator buildPackages} ${
            package.overrideAttrs ({
              buildPhase =
                let
                  libgestalt = lib.gestaltCore.cpp (ir // { initialState = ir.showcaseState; });
                in
                ''
                  $CXX -O3 -flto -I ${libgestalt}/include -I ${nlohmann_json}/include main.cpp -o main ${libgestalt}/lib/libgestalt.a -lcurl
                '';
            })
          }/bin/${ir.name} > capture.ansi

          ansilove capture.ansi -o $out/screenshot.png

        '';
  };

})
