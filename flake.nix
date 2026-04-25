{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixFork.url = "github:lomenzel/nix";
    nix-appimage.url = "github:ralismark/nix-appimage";
    nix-appimage.inputs.nixpkgs.follows = "nixpkgs";
    nix-appimage.inputs.flake-utils.follows = "flake-utils";
    flake-utils.url = "github:numtide/flake-utils";
    systems.url = "github:nix-systems/default";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    wechselbalg = {
      type = "git";
      url = "https://rad-node.menzel.lol/rad:zpRitanyyPyavYSf6RWXeXry864M.git";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
      wechselbalg,
      ...
    }@inputs:
    let
      eachSystem =
        f:
        nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
          system:
          f {
            inherit system;
            pkgs = import nixpkgs {
              inherit system;
              overlays = [
                wechselbalg.overlays.default
                self.overlays.default
              ];
            };
          }
        );
      treefmtEval = eachSystem ({ pkgs, ... }: treefmt-nix.lib.evalModule pkgs ./treefmt.nix);
    in
    {
      overlays.default =
        final: prev:
        let
          nix-appimage-packages =
            (import inputs.nix-appimage.inputs.nixpkgs {
              localSystem = final.stdenv.buildPlatform;
              crossSystem = final.stdenv.hostPlatform;
            }).pkgsStatic;
        in
        {
          lib =
            prev.lib
            // import ./src/lib {
              inherit (final) lib;
            };
        }
        // {
          gestaltPlatform = (
            import ./src/platform {
              pkgs = final;
              inherit inputs;
            }
          );
        };

      devShells = eachSystem (
        { system, pkgs }:
        {
          default = self.packages.${system}.counter.overrideAttrs (old: {
            buildInputs = [
              inputs.nixFork.packages.${system}.nix
              pkgs.nodejs
              pkgs.nixd
              pkgs.lldb
              (pkgs.writeShellScriptBin "clangd" ''
                #!/bin/sh
                exec "${pkgs.clang-tools}/bin/clangd" --query-driver="$(which g++)" $@
              '')
              (pkgs.writeShellScriptBin "qmlls" ''
                #!/bin/sh
                exec "${pkgs.kdePackages.qtdeclarative}/bin/qmlls" \
                      --no-cmake-calls \
                      -I ${pkgs.kdePackages.qtdeclarative}/lib/qt-6/qml \
                      -I ${pkgs.kdePackages.kirigami.unwrapped}/lib/qt-6/qml \
                       $@
              '')
            ]
            ++ old.buildInputs;
            CMAKE_EXPORT_COMPILE_COMMANDS = true;
            LANG = "C.UTF-8";
            shellHook = ''
              # Qt/KDE runtime paths so locally-built (unwrapped) binaries find QML modules & plugins.
              # NIXPKGS_QML_SEARCH_PATHS is populated by wrapQtAppsHook from all Qt/KDE buildInputs.
              export QML2_IMPORT_PATH="$NIXPKGS_QML_SEARCH_PATHS''${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"

              # Generate .clangd config with Qt base include paths and query-driver.
              # CMake's compile_commands.json only has per-module dirs (e.g. include/QtWidgets)
              # but not the parent dirs needed to resolve transitive includes like
              # <QtWidgets/qapplication.h>. Nix's gcc-wrapper injects these via
              # NIX_CFLAGS_COMPILE, but clangd doesn't see them.
              cat > .clangd <<EOF
              CompileFlags:
                CompilationDatabase: build/
                Add:
                  - -isystem
                  - ${pkgs.kdePackages.qtbase}/include
                  - -isystem
                  - ${pkgs.kdePackages.qtdeclarative}/include
              EOF
            '';
          });
        }
      );

      # example usage
      packages = eachSystem (
        { system, pkgs, ... }:

        {

          counter = pkgs.gestaltPlatform.buildApplication {
            src = ./examples/counter;
          };

        }
      );

      # for `nix fmt`
      formatter = eachSystem ({ system, ... }: treefmtEval.${system}.config.build.wrapper);
      # for `nix flake check`

      checks = eachSystem (
        { system, pkgs, ... }:

        self.packages.${system}
        // {
          fmt = treefmtEval.${system}.config.build.check self;
        }
      );
    };
}
