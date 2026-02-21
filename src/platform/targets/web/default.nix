{ pkgs, lib, ... }:
{

  gestaltPlatform.targets.web = {

    capabilities = import ./capabilities.nix;

    buildApplication =
      {
        initialState,
        stateType,
        actions,
        view,
        name,
        author,
        version,
        title,
      }@ir:
      let
        appJs = pkgs.writeText "app.js" ''
          var state = ${lib.toJS initialState};

          actions = ${lib.toJS (builtins.mapAttrs (name: action: action.function) actions)}


          var actionsParams = ${
            lib.toJS (
              builtins.mapAttrs (
                _: action:
                let
                  paramType =
                    if builtins.hasAttr "paramType" action && builtins.typeOf action.paramType == "set" then
                      action.paramType
                    else
                      null;
                  fields = if paramType != null && builtins.hasAttr "fields" paramType then paramType.fields else { };
                  innerFields =
                    if
                      builtins.hasAttr "params" fields
                      && builtins.typeOf fields.params == "set"
                      && builtins.hasAttr "fields" fields.params
                    then
                      fields.params.fields
                    else
                      fields;
                in
                builtins.attrNames innerFields
              ) actions
            )
          };

          function callView(s) {
            return ${lib.toJS view}(s);
          }
        '';

        indexHTML = pkgs.writeText "index.html" ''
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

            <script src="app.js"></script>
            <script src="runtime.js"></script>
          </body>
          </html>
        '';

        webDir = pkgs.runCommand "${name}-web" { } ''
          mkdir -p $out
          cp ${indexHTML} $out/index.html
          cp ${appJs} $out/app.js
          cp ${./styles.css} $out/styles.css
          cp ${./runtime.js} $out/runtime.js

          cat > $out/server.py <<'PY'
          #!/usr/bin/env python3
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
          PY

          chmod +x $out/server.py
        '';
      in
      pkgs.writeShellScriptBin name ''
        echo "Serving ${title} at http://localhost:8080"
        cd ${webDir}
        ${pkgs.python3}/bin/python3 server.py 8080
      '';

  };
}
