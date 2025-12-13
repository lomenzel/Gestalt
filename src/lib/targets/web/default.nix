pkgs: {

  effects = {
    noop = "Placeholder_nativeEffectReference_NoOp";
  };
  buildApplication =
    {
      initialState,
      stateType,
      actions,
      types,
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
${jsFunctions}

let state = ${exprToJS initialState};

const actions = {
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
        hasPtRef = builtins.typeOf pt == "set" && builtins.hasAttr "_type" pt && pt._type == "typeRef";
        paramsFields =
          if hasPtRef && builtins.hasAttr pt.name types then
            let
              t = builtins.getAttr pt.name types;
              hasParamsField = builtins.hasAttr "fields" t && builtins.hasAttr "params" t.fields;
              paramsType = if hasParamsField then t.fields.params else null;
              resolved =
                if paramsType == null then [ ]
                else if
                  builtins.typeOf paramsType == "set"
                  && builtins.hasAttr "_type" paramsType
                  && paramsType._type == "typeRef"
                  && builtins.hasAttr paramsType.name types
                then
                  let pt2 = builtins.getAttr paramsType.name types;
                  in if builtins.hasAttr "fields" pt2 then builtins.attrNames pt2.fields else [ ]
                else if
                  builtins.typeOf paramsType == "set"
                  && builtins.hasAttr "_type" paramsType
                  && paramsType._type == "struct"
                then
                  builtins.attrNames paramsType.fields
                else [ ];
            in resolved
          else [ ];
        fields = pkgs.lib.concatStringsSep ", " (builtins.map (f: "\"" + f + "\"") paramsFields);
      in
      name + ": [" + fields + "]"
    ) actions
  )}
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
    const result = actions[actionName](
      params ? { state, params } : { state }
    );
    state = result.state;
    log(`Action executed: ${"$"}{actionName}`);
    renderState();
  } catch (e) {
    log(`Error: ${"$"}{e.message}`);
  }
});

renderActions();
renderState();
renderParams(actionSelect.value);
</script>

      </body>
      </html>

      '';
    in
    indexHTML;

}
