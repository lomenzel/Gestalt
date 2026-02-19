pkgs: {

  capabilities = import ../cli/capabilities.nix;
  buildApplication =
    {
      initialState,
      stateType,
      actions,
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
      indexHTML = pkgs.writeText "index.html" ''
      <!DOCTYPE html>
      <html lang="en">
      <head>
          <meta charset="UTF-8">
          <title>${title}</title>
      </head>
      <body>

        <h1>Welcome to ${title} v${version} by ${author.name}!</h1>

     <script>
${jsHelpers.generalHelpers}

${jsFunctions}

state = ${exprToJS initialState};

actions = {
  ${pkgs.lib.concatStringsSep "," (
    pkgs.lib.mapAttrsToList (name: val: name + ": " + val.function) actions
  )}
};

const actionsParams = {
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

function invokeAction(actionName, params) {
  result = actions[actionName]({state: state, params: params});
  state = result.state;
  log("Action performed: " + actionName);
  executeEffect(result.effect);
  renderState();
}

function executeEffect(effect) {
  log("Executing effect: " + effect.id);
  effectFunctions[effect.id](effect.params);
}

effectFunctions = {
  "noop": () => {
    // Do nothing
  },
  "log": (params) => {
    log("LOG EFFECT: " + params.message);
  },
  "httpRequest": (params) => {
    if (params.method.toUpperCase() === "GET") {
      fetch(params.url)
        .then(resp => resp.text().then(body => ({
          status: resp.status,
          body: body,
          headers: Object.fromEntries(resp.headers.entries())
        })))
        .then(data => {
          invokeAction(params.callBackActionId, data);
        })
        .catch(e => {
          log("HTTP Error: " + e.message);
        });
    } else {
      fetch(params.url, {
        method: params.method,
        body: params.body,
        headers: params.headers || {}
      })
        .then(resp => resp.text().then(body => ({
          status: resp.status,
          body: body,
          headers: Object.fromEntries(resp.headers.entries())
        })))
        .then(data => {
          invokeAction(params.callBackActionId, data);
        })
        .catch(e => {
          log("HTTP Error: " + e.message);
        });
    }
  },
  "random": (params) => {
    const min = params.from;
    const max = params.to;
    const result = Math.floor(Math.random() * (max - min + 1)) + min;
    invokeAction(params.callbackActionId, {
      result: result
    });
  },
  "invokeAction": (params) => {
    invokeAction(params.actionId, params.params);
  }
};

/* ---------- UI ---------- */

document.body.innerHTML += `
  <div style="font-family: monospace; max-width: 800px;">
    <h2>State</h2>
    <pre id="stateView"></pre>

    <h2>Actions</h2>
    <select id="actionSelect"></select>

    <div id="paramsContainer"></div>

    <button id="runBtn">Run action</button>

    <h2>Log</h2>
    <pre id="log"></pre>
  </div>
`;

const stateView = document.getElementById("stateView");
const actionSelect = document.getElementById("actionSelect");
const paramsContainer = document.getElementById("paramsContainer");
const logView = document.getElementById("log");
const runBtn = document.getElementById("runBtn");

function renderState() {
  stateView.textContent = JSON.stringify(state, null, 2);
}

function log(msg) {
  logView.textContent += msg + "\n";
}

function renderActions() {
  Object.keys(actions).forEach(name => {
    const opt = document.createElement("option");
    opt.value = name;
    opt.textContent = name;
    actionSelect.appendChild(opt);
  });
}

function renderParams(actionName) {
  paramsContainer.innerHTML = "";
  const fields = actionsParams[actionName] || [];
  if (fields.length === 0) return;

  fields.forEach(f => {
    const label = document.createElement("label");
    label.textContent = f;
    label.style.display = "block";

    const input = document.createElement("input");
    input.dataset.field = f;
    input.style.width = "100%";

    paramsContainer.appendChild(label);
    paramsContainer.appendChild(input);
  });
}

actionSelect.addEventListener("change", e => {
  renderParams(e.target.value);
});

runBtn.addEventListener("click", () => {
  const actionName = actionSelect.value;
  const fields = actionsParams[actionName] || [];
  let params = undefined;

  if (fields.length > 0) {
    params = {};
    paramsContainer.querySelectorAll("input").forEach(input => {
      const key = input.dataset.field;
      try {
        params[key] = JSON.parse(input.value);
      } catch {
        params[key] = input.value;
      }
    });
  }

  try {
    invokeAction(actionName, params ? params : {});
  } catch (e) {
    log("Error: " + e.message);
  }
});

renderActions();
renderState();
renderParams(actionSelect.value);
</script>

      </body>
      </html>

      '';
      webDir = pkgs.runCommand "${name}-web" {} ''
        mkdir -p $out
        cp ${indexHTML} $out/index.html
      '';
    in
    pkgs.writeShellScriptBin name ''
      echo "Serving ${title} at http://localhost:8080"
      cd ${webDir}
      ${pkgs.python3}/bin/python3 -m http.server 8080
    '';

}
