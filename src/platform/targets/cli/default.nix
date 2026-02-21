{ pkgs, lib, ... }:
{
  gestaltPlatform.targets.cli = {

    capabilities = import ./capabilities.nix;
    buildApplication =
      {
        initialState,
        stateType,
        actions,
        name,
        view,
        author,
        version,
        title,
      }@ir:
      let
        jsFile = pkgs.writeText "app.js" ''
          state = ${lib.toJS initialState}

          actions = ${lib.toJS (builtins.mapAttrs (name: action: action.function) actions)}

          const actionsParams = ${
            lib.toJS (builtins.mapAttrs (_: action: action.paramType |> (t:
              t.fields
            )) actions)
          };

          function invokeAction(actionName, params) {
            result = actions[actionName]({state: state, params: params});
            state = result.state;
            console.log("Action performed:", actionName);
            executeEffect(result.effect);
            renderUI();
          };

          const stdin = process.openStdin();
          // Ordered list of actions from the current view rendering
          let currentViewActions = [];
          let pendingAction = null;
          stdin.addListener("data", function(d) {
            const input = d.toString().trim();

            if (pendingAction) {
              try {
                const params = JSON.parse(input);
                console.log("you entered params:", params);
                invokeAction(pendingAction, params);
                pendingAction = null;
              } catch (e) {
                pendingAction = null;
                console.log(e);
              }
              return;
            }

            if (input === "_exit") {
              console.log("Exiting...");
              process.exit();
            }

            // Check if input is a number referencing a displayed action
            const num = parseInt(input, 10);
            if (!isNaN(num) && num >= 1 && num <= currentViewActions.length) {
              const chosen = currentViewActions[num - 1];
              if (chosen.params !== undefined) {
                invokeAction(chosen.actionId, chosen.params);
              } else {
                const expected = actionsParams[chosen.actionId] || [];
                if (expected.length > 0) {
                  pendingAction = chosen.actionId;
                  askForParams(chosen.actionId, expected);
                } else {
                  invokeAction(chosen.actionId, {});
                }
              }
            } else if (actions[input]) {
              // Direct action name input – find first matching view action with params
              const viewAction = currentViewActions.find(a => a.actionId === input && a.params !== undefined);
              if (viewAction) {
                invokeAction(input, viewAction.params);
              } else {
                const expected = actionsParams[input] || [];
                if (expected.length && expected.length > 0) {
                  pendingAction = input;
                  askForParams(input, expected);
                } else {
                  invokeAction(input, { });
                }
              }
            } else {
              console.log("Unknown action. Please try again.");
              renderUI();
            }
          });

          console.log("Welcome to ${title} v${version} by ${author.name}!");

          function renderUI() {
            let ui;
            
            ui = ${lib.toJS view}(state);

            // Collect all actions from the view in order
            currentViewActions = [];
            if (ui.actions && ui.actions.length) {
              ui.actions.forEach(a => {
                if (a && a.actionId) {
                  currentViewActions.push(a);
                }
              });
            }
            
            if (Array.isArray(ui)) ui = ui[0];

            if (ui.elements && ui.elements.length) {
              ui.elements.forEach(el => console.log("  " + el.content));
            }
            if (currentViewActions.length) {
              console.log("");
              currentViewActions.forEach((a, i) => {
                console.log("  [" + (i + 1) + "] " + (a.content || a.actionId));
              });
              console.log("");
              console.log("Enter number, action name, or '_exit' to quit:");
            } else {
              console.log("No actions available. Enter '_exit' to quit.");
            }
          }

          function askForInput(state) {
            renderUI();
          }

          function askForParams(actionName, fields) {
              console.log(`Action '${"$"}{actionName}' requires params: ${"$"}{fields.join(", ")}`);
              console.log(`Enter params as JSON (e.g. {${"$"}{fields.map((field) =>  "\"" + field + "\" : <value>").join(",")}}):`);
          }

          function executeEffect(effect) {
          console.log("Executing effect:", effect.id);
            effectFunctions[effect.id](effect.params);
          }value

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

  };
}
