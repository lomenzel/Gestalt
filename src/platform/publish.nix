{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  gestaltPlatform.publish =
    modules:
    let
      gnu64pkgs = pkgs.pkgsCross.gnu64;
      inherit (config.gestaltPlatform) buildApplication;
      webIR = lib.mkGestaltIR {
        target = config.gestaltPlatform.targets.web;
        modules = modules;
      };
      web = buildApplication {
        inherit modules;
        target = config.gestaltPlatform.targets.web;
      };
      tui = pkgs.gestaltPlatform.buildApplication {
        inherit modules;
        target = pkgs.gestaltPlatform.targets.tui;
      };
      tuiCross =
        crossSystem:
        pkgs.pkgsCross.${crossSystem}.gestaltPlatform.buildApplication {
          inherit modules;
          target = pkgs.pkgsCross.${crossSystem}.gestaltPlatform.targets.tui;
        };
      tuiAppimageCross =
        crossSystem:
        pkgs.pkgsCross.${crossSystem}.lib.mkAppImage {
          program = "${tuiCross crossSystem}/bin/${webIR.name}";
        };

      fullTarget = {
        inherit (pkgs.gestaltPlatform.targets.web) capabilities;
        buildApplication =
          ir:
          pkgs.runCommand "full-build" { } ''
            mkdir -p $out/app
            cp -r ${web}/public/* $out/app
            cp ${
              pkgs.writeText "" (
                builtins.readFile ./landing.html
                |> builtins.replaceStrings [ "%appname%" "%apptitle%" ] [ webIR.name webIR.title ]
              )
            } $out/index.html

            mkdir -p $out/download
            (cd ${web}/public && ${pkgs.zip}/bin/zip -r $out/download/${webIR.name}.zip .)
            ${builtins.concatStringsSep "\n" (
              builtins.map
                (crossSystem: ''
                  cp ${tuiAppimageCross crossSystem} $out/download/${webIR.name}-tui-${crossSystem}.AppImage
                '')
                ([
                  "gnu64"
                  "gnu32"
                  "armv7l-hf-multiplatform"
                  "aarch64-multiplatform"
                  "riscv64"
                  "ppc64"
                ])
            )}
            ${builtins.concatStringsSep "\n" (
              builtins.map
                (crossSystem: ''
                  cp ${
                    (tuiCross crossSystem).overrideAttrs {
                      doCheck = false;
                      checkPhase = "true";
                    }
                  }/bin/${webIR.name}.exe $out/download/${webIR.name}-tui-${crossSystem}.exe
                '')
                [
                  # "mingwW64"
                  # "mingw32"
                ]
            )}
            cp ${
              (tui.override (old: {
                ir = old.ir // {
                  initialState = old.ir.showcaseState;
                };
              })).screenshot
            }/screenshot.png $out/download/${webIR.name}-tui.png
            cp ${
              (web.override (old: {
                ir = old.ir // {
                  initialState = old.ir.showcaseState;
                };
              })).screenshot
            }/screenshot.png $out/download/${webIR.name}-web.png
          '';
      };
      full = config.gestaltPlatform.buildApplication {
        inherit modules;
        target = fullTarget;
      };
    in
    pkgs.stdenv.mkDerivation {
      dontUnpack = true;
      name = "${webIR.name}-publish";

      installPhase = ''
        mkdir -p $out

        ln -s ${full} $out/public

        mkdir -p $out/bin
        cp ${pkgs.writeShellScript "publish" ''
          set -euo pipefail

          IPNS_KEY=""
          IPFS_FLAGS=""

          # 1. Parse arguments
          while [[ $# -gt 0 ]]; do
            case $1 in
              --ipns)
                IPNS_KEY="$2"
                shift 2
                ;;
              --ipfs-flags)
                IPFS_FLAGS="$2"
                shift 2
                ;;
              *)
                echo "Unknown argument: $1" >&2
                echo "Usage: $0 [--ipns <key_name>] [--ipfs-flags <flags>]" >&2
                exit 1
                ;;
            esac

          done



          # 2. Upload to IPFS
          # ipfs add pins the content locally by default.
          if ! cid=$(${pkgs.kubo}/bin/ipfs add --cid-version=1 $IPFS_FLAGS -r ${full} | tail -n1); then
            echo "" >&2
            echo -e "\033[31m[Error] Failed to publish to IPFS\033[0m" >&2
            echo "This framework uses IPFS (InterPlanetary File System) to host and publish your application." >&2
            echo "If you haven't set up IPFS yet, please ensure the IPFS daemon is running." >&2
            echo "refer to https://wiki.nixos.org/wiki/IPFS" >&2
            exit 1
          fi

          echo "You can access your application now on https://''${cid}".ipfs.menzel.lol

          # 3. Add to WebUI "Files" (MFS)
          # We define metadata variables. We use Nix 'or' to provide defaults if attributes are missing.
          AUTHOR="${webIR.author.name}"
          APP_NAME="${webIR.title}"
          VERSION="${webIR.version}"
          TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

          # Define the target directory structure
          MFS_BASE_DIR="/GestaltApplications/''${AUTHOR}/''${APP_NAME}/''${VERSION}"

          # Create a specific folder for this build using timestamp + short CID to ensure uniqueness/sorting
          TARGET_PATH="''${MFS_BASE_DIR}/''${cid}"

          # Ensure the directory hierarchy exists
          ${pkgs.kubo}/bin/ipfs $IPFS_FLAGS files mkdir -p "''${MFS_BASE_DIR}"

          ${pkgs.kubo}/bin/ipfs $IPFS_FLAGS files rm -rf "''${TARGET_PATH}" || true

          # Copy the uploaded content to the MFS path
          if ${pkgs.kubo}/bin/ipfs $IPFS_FLAGS files cp "/ipfs/''${cid}" "''${TARGET_PATH}"; then
             echo " - Added to: ''${TARGET_PATH}"
          else
             echo -e "\033[33m[Warning] Could not add to MFS (WebUI files).\033[0m" >&2
          fi

          # 4. Publish to IPNS (Optional)
          if [[ -n "''${IPNS_KEY}" ]]; then

            # Check if key exists and get the ID
            IPNS_ID=$(${pkgs.kubo}/bin/ipfs $IPFS_FLAGS key list -l | awk -v key="''${IPNS_KEY}" '$2==key {print $1}')

            if [[ -z "''${IPNS_ID}" ]]; then
              echo -e "\033[31m[Error] IPNS key \"''${IPNS_KEY}\" does not exist.\033[0m" >&2
              echo "Please generate it first using: ipfs key gen ''${IPNS_KEY}" >&2
              exit 1
            fi

            if ${pkgs.kubo}/bin/ipfs $IPFS_FLAGS name publish --key="''${IPNS_KEY}" "/ipfs/''${cid}"; then
              echo "URL: https://''${IPNS_ID}".ipns.menzel.lol
            else
              echo -e "\033[31m[Error] Failed to publish to IPNS\033[0m" >&2
              exit 1
            fi
          fi
        ''} $out/bin/${webIR.name}-publish
      '';
    };
}
