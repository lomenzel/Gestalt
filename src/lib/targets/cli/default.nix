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
      jsFile = pkgs.writeText "app.js" ''
        ${jsFunctions}

        state = ${

          exprToJS initialState
        }

        actions = {
          ${pkgs.lib.concatStringsSep "," (
            pkgs.lib.mapAttrsToList (name: val: name + ": " + val.function) actions
          )}
        }

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
                        if paramsType == null then
                          [ ]
                        else if
                          builtins.typeOf paramsType == "set"
                          && builtins.hasAttr "_type" paramsType
                          && paramsType._type == "typeRef"
                          && builtins.hasAttr paramsType.name types
                        then
                          let
                            pt2 = builtins.getAttr paramsType.name types;
                          in
                          if builtins.hasAttr "fields" pt2 then builtins.attrNames pt2.fields else [ ]
                        else if
                          builtins.typeOf paramsType == "set"
                          && builtins.hasAttr "_type" paramsType
                          && paramsType._type == "struct"
                        then
                          builtins.attrNames paramsType.fields
                        else
                          [ ];
                    in
                    resolved
                  else
                    [ ];
                fields = pkgs.lib.concatStringsSep ", " (builtins.map (f: "\"" + f + "\"") paramsFields);
              in
              name + ": [" + fields + "]"
            ) actions
          )}
        };

        const stdin = process.openStdin();
        let pendingAction = null;
        stdin.addListener("data", function(d) {
          const input = d.toString().trim();

          if (pendingAction) {
            try {
              const params = JSON.parse(input);
              const result = actions[pendingAction]({state: state, params: params});
              state = result.state;
              console.log("Action performed:", pendingAction);
              pendingAction = null;
              askForInput(state);
            } catch (e) {
              console.log("Invalid params JSON. Please enter valid JSON for params");
            }
            return;
          }

          if (input === "_exit") {
            console.log("Exiting...");
            process.exit();
          } else if (actions[input]) {
            const expected = actionsParams[input] || [];
            if (expected.length && expected.length > 0) {
              pendingAction = input;
              askForParams(input, expected);
            } else {
              const result = actions[input]({state: state});
              state = result.state;
              console.log("Action performed:", input);
              askForInput(state);
            }
          } else {
            console.log("Unknown action. Please try again.");
            askForInput(state);
          }
        });

        console.log("Welcome to ${title} v${version} by ${author.name}!");


        function askForInput(state) {
            console.log("Current state: ", state);
            console.log("Enter action (${
              pkgs.lib.concatStringsSep ", " (pkgs.lib.mapAttrsToList (name: val: name) actions)
            }) or '_exit' to quit:");

        }

        function askForParams(actionName, fields) {
            console.log(`Action '${"$"}{actionName}' requires params: ${"$"}{fields.join(", ")}`);
            console.log(`Enter params as JSON (e.g. {${"$"}{fields.map((field) =>  "\"" + field + "\" : <value>").join(",")}}):`);
        }

        askForInput(state)

      '';
    in
    pkgs.writeShellScriptBin name ''
      ${pkgs.nodejs}/bin/node ${jsFile};
    '';

}
