{
  ir,
  writeText,
  runCommand,
  lib,
  makeFontsConf,
  dejavu_fonts,
  chromium,
  writeShellScript,
  buildPackages,
  stdenv,
  python3,
}:
let
  inherit (ir)
    title
    author
    version
    name
    ;
  indexHTML = writeText "index.html" ''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>${title}</title>
      <link rel="stylesheet" href="styles.css">
    </head>
    <body>
      <div id="app">
        <div class="app-header">
          <h1>${title}</h1>
          <div class="meta">v${version} &middot; ${author.name}</div>
        </div>
        <div id="viewContainer"></div>
      </div>

      <div id="paramModal" class="modal-overlay">
        <div class="modal-content">
          <h3 id="modalTitle">Parameters</h3>
          <div id="modalFields"></div>
          <div class="modal-actions">
            <button id="modalCancel" class="btn-cancel">Cancel</button>
            <button id="modalSubmit" class="btn-submit">Submit</button>
          </div>
        </div>
      </div>

      <script src="lib/generated/core.js"></script>
      <script src="runtime.js"></script>
    </body>
    </html>
  '';

  public = runCommand "${name}-public-assets" { } ''
    mkdir -p $out/lib/generated
    cp ${indexHTML} $out/index.html
    cp ${./styles.css} $out/styles.css
    cp ${./runtime.js} $out/runtime.js

    # copy the ESM core produced by lib.gestaltCore.js and produce a
    # browser-friendly variant that exposes globals on window
    cp ${lib.gestaltCore.js ir} $out/lib/generated/core.esm.js
    # TODO gestaltCore should probably produce a browser-friendly version :)
    sed \
      -e 's/^export default/window.GestaltCore =/' \
      $out/lib/generated/core.esm.js > $out/lib/generated/core.js

    rm $out/lib/generated/core.esm.js
  '';
  public-screenshot = runCommand "${name}-public-assets" { } ''
    mkdir -p $out/lib/generated
    cp ${indexHTML} $out/index.html
    cp ${./styles.css} $out/styles.css
    cp ${./runtime.js} $out/runtime.js

    # copy the ESM core produced by lib.gestaltCore.js and produce a
    # browser-friendly variant that exposes globals on window
    cp ${lib.gestaltCore.js (ir // {initialState = ir.showcaseState;})} $out/lib/generated/core.esm.js
    # TODO gestaltCore should probably produce a browser-friendly version :)
    sed \
      -e 's/^export default/window.GestaltCore =/' \
      $out/lib/generated/core.esm.js > $out/lib/generated/core.js

    rm $out/lib/generated/core.esm.js
  '';
in
runCommand name
  {
    passthru = {
      screenshot =
        buildPackages.runCommand "${name}-web-screenshot.png"
          {
            nativeBuildInputs = [ buildPackages.chromium ];
            # Critical: The Nix sandbox has no system fonts. Without this,
            # Chromium will render all text as invisible or square boxes.
            FONTCONFIG_FILE = buildPackages.makeFontsConf {
              fontDirectories = [ buildPackages.dejavu_fonts ];
            };
          }
          ''
            # Chromium requires a writable HOME to store temporary profile data
            export HOME=$(mktemp -d)

            echo "Taking headless screenshot of ${name}..."
            mkdir -p $out

            cp -r ${public-screenshot} ./app-copy
            chmod -R +w ./app-copy
            echo "* { transition: none !important; animation: none !important; }" >> ./app-copy/styles.css

            # Use headless Chromium to render the local HTML file.
            # ${stdenv.hostPlatform.emulator buildPackages}
            chromium \
              --headless=new \
              --no-sandbox \
              --disable-dev-shm-usage \
              --disable-gpu \
              --hide-scrollbars \
              --window-size=960,600 \
              --allow-file-access-from-files \
              --virtual-time-budget=4000 \
              --screenshot=$out/screenshot.png \
              "file://$PWD/app-copy/index.html"
          '';
    };
  }
  ''
    mkdir -p $out/public
    cp -r ${public}/* $out/public/

    mkdir -p $out/bin
    cp ${writeShellScript "${name}-server" ''
      cd ${public}
      echo "Starting server for ${name} on port 8080..."
      ${lib.getExe python3} ${writeText "server.py" ''
        from http.server import SimpleHTTPRequestHandler, HTTPServer
        import sys

        class CORSRequestHandler(SimpleHTTPRequestHandler):
            def end_headers(self):
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, PUT, DELETE')
                self.send_header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept')
                SimpleHTTPRequestHandler.end_headers(self)

            def do_OPTIONS(self):
                self.send_response(200, "OK")
                self.send_header('Content-Length', '0')
                self.end_headers()

        if __name__ == '__main__':
            port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
            server = HTTPServer(('0.0.0.0', port), CORSRequestHandler)
            print(f"Serving on port {port}")
            server.serve_forever()
      ''} 8080
    ''} $out/bin/${name}
  ''
