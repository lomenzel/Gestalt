pkgs: {

  capabilities = import ./capabilities.nix;
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
      jsFile = pkgs.writeText "app.js" ''
        ${jsHelpers.generalHelpers}

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
          console.log("Action performed:", actionName);
          executeEffect(result.effect);

        };

        const stdin = process.openStdin();
        let pendingAction = null;
        stdin.addListener("data", function(d) {
          const input = d.toString().trim();

          if (pendingAction) {
            try {
              const params = JSON.parse(input);
              console.log("you entered params:", params);
              invokeAction(pendingAction, params);
              pendingAction = null;
              askForInput(state);
            } catch (e) {
              pendingAction = null;
              console.log(e);
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
              invokeAction(input, { });
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

        function executeEffect(effect) {
        console.log("Executing effect:", effect.id);
          effectFunctions[effect.id](effect.params);
        }

        effectFunctions = {
          "noop": () => {
            // Do nothing
          },
          "log": (params) => {
            console.log("LOG EFFECT:", params.message);
          },
          "httpRequest": (params) => {
          
            const https = require('https');

            if (params.method.toUpperCase() === "GET") {
              https.get(params.url, (resp) => {
                let data = "";
                resp.on("data", (chunk) => {
                  data += chunk;
                });
                resp.on("end", () => {
                  invokeAction(params.callBackActionId, {
                    status: resp.statusCode,
                    body: data,
                    headers: resp.headers
                  });
                });
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
        }


        askForInput(state)

      '';
    in
    pkgs.writeShellScriptBin name ''
      ${pkgs.nodejs}/bin/node ${jsFile};
    '';

}
