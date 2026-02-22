{
  stdenv,
  ir,
  curl,
  nlohmann_json,
  lib,
}:
let 
  libgestalt = lib.gestaltCore.cpp ir;
in 
stdenv.mkDerivation {
  pname = ir.name;
  version = ir.version;
  src = ./src;
  buildInputs = [ libgestalt curl nlohmann_json ];
  buildPhase = ''
    g++ -O3 -flto -I ${libgestalt}/include -I ${nlohmann_json}/include main.cpp -o main ${libgestalt}/lib/libgestalt.a -lcurl
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
  };
}
