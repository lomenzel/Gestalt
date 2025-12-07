{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix = {
      url = "github:lomenzel/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix,
    }:
    {
      lib."x86_64-linux" = import ./src/lib {
        pkgs = import nixpkgs { system = "x86_64-linux"; };
        nix = nix.packages."x86_64-linux".default;
        inherit nixpkgs;
      };
      packages."x86_64-linux" = rec {
        default = examples.counter.cli;
        examples.counter.cli = self.lib."x86_64-linux".buildGestaltApplication (
          (import ./examples/counter)
          // {
            target = self.lib."x86_64-linux".targets.cli;
          }
        );
      };

    };
}
