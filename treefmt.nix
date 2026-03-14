{ pkgs, ... }:
{
  programs = {
    nixfmt.enable = true;
    yamlfmt.enable = true;
    prettier = {
      enable = true;
      excludes = [
        #  "generated/**"
      ];
    };
  };
}
