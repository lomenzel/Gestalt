pkgs: {

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
      functions,
      title,
    }@ir:
    let
      jsHelpers = import ../js.nix pkgs;
      inherit (jsHelpers) toJS exprToJS;

      jsFunctions = pkgs.lib.concatStringsSep "\n\n" (
        builtins.map (func: toJS func) (pkgs.lib.attrsToList functions)
      );

      appJs = pkgs.writeText "app.js" ''
        ${jsHelpers.generalHelpers}

        ${jsFunctions}

        var state = ${exprToJS initialState};

        var actions = {
          ${pkgs.lib.concatStringsSep "," (
            pkgs.lib.mapAttrsToList (name: val: name + ": " + val.function) actions
          )}
        };

        var actionsParams = {
          ${pkgs.lib.concatStringsSep "," (
            pkgs.lib.mapAttrsToList (
              name: val:
              let
                pt = val.paramType;
                hasPt = builtins.typeOf pt == "set" && builtins.hasAttr "_type" pt && builtins.hasAttr "params" pt.fields;
                paramsFields = if hasPt then builtins.attrNames pt.fields.params.fields else [ ];
                fields = pkgs.lib.concatStringsSep ", " (builtins.map (f: "\"" + f + "\"") paramsFields);
              in
              name + ": [" + fields + "]"
            ) actions
          )}
        };

        function callView(s) {
          return ${view}({__value: s});
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

}
