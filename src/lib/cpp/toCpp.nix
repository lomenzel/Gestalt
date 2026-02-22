{lib, pkgs, ...}:
let 
  toCpp' = nixExpr: reifiedFunctions: {
    text = ''
      /* todo */
    '';
    inherit reifiedFunctions;
  };
in  {
  lib.toCpp = nixExpr: (toCpp' nixExpr {}).text;
}