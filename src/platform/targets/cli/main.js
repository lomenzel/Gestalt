import { core, actionParamTypes, meta } from "./generated/core.js";
import https from "https";

console.log(`${meta.title} started!`);

const stdin = process.stdin;
stdin.setEncoding("utf8");

let currentViewActions = [];
let pendingAction = null;

function invokeAction(actionName, params) {
  const effect = core.dispatch(actionName, params);
  console.log("Action performed:", actionName);
  executeEffect(effect);
  renderUI();
}

stdin.on("data", (d) => {
  const input = d.toString().trim();

  if (pendingAction) {
    try {
      const params = JSON.parse(input);
      invokeAction(pendingAction, params);
    } catch (e) {
      console.log("Invalid JSON:", e.message);
    }
    pendingAction = null;
    return;
  }

  if (input === "_exit") {
    console.log("Exiting...");
    process.exit(0);
  }

  const num = parseInt(input, 10);

  if (!Number.isNaN(num) && num >= 1 && num <= currentViewActions.length) {
    const chosen = currentViewActions[num - 1];

    if (chosen.params !== undefined) {
      invokeAction(chosen.actionId, chosen.params);
    } else {
      const expected = actionParamTypes[chosen.actionId] || [];
      if (expected.length > 0) {
        pendingAction = chosen.actionId;
        askForParams(chosen.actionId, expected);
      } else {
        invokeAction(chosen.actionId, {});
      }
    }
    return;
  }

  if (actionParamTypes[input] !== undefined) {
    const viewAction = currentViewActions.find(
      (a) => a.actionId === input && a.params !== undefined
    );

    if (viewAction) {
      invokeAction(input, viewAction.params);
    } else {
      const expected = actionParamTypes[input] || [];
      if (expected.length > 0) {
        pendingAction = input;
        askForParams(input, expected);
      } else {
        invokeAction(input, {});
      }
    }
    return;
  }

  console.log("Unknown action.");
  renderUI();
});

function renderUI() {
  let ui = core.view;

  currentViewActions = [];

  if (ui.actions && ui.actions.length) {
    ui.actions.forEach((a) => {
      if (a && a.actionId) {
        currentViewActions.push(a);
      }
    });
  }

  if (Array.isArray(ui)) ui = ui[0];

  if (ui.elements && ui.elements.length) {
    ui.elements.forEach((el) => console.log("  " + el.content));
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

function askForParams(actionName, fields) {
  console.log(
    `Action '${actionName}' requires params: ${fields.join(", ")}`
  );
  console.log(
    `Enter params as JSON (e.g. {${fields
      .map((f) => `"${f}": <value>`)
      .join(", ")}}):`
  );
}

function executeEffect(effect) {
  if (!effect || !effect.id) return;

  const fn = effectFunctions[effect.id];
  if (fn) {
    fn(effect.params || {});
  } else {
    console.log("Unknown effect:", effect.id);
  }
}

const effectFunctions = {
  noop: () => { },

  log: (params) => {
    console.log("LOG EFFECT:", params.message);
  },

  httpRequest: (params) => {
    if (params.method?.toUpperCase() === "GET") {
      https.get(params.url, (resp) => {
        let data = "";

        resp.on("data", (chunk) => {
          data += chunk;
        });

        resp.on("end", () => {
          invokeAction(params.callBackActionId, {
            status: resp.statusCode,
            body: data,
            headers: resp.headers,
          });
        });
      });
    }
  },

  random: (params) => {
    const min = params.from;
    const max = params.to;
    const result =
      Math.floor(Math.random() * (max - min + 1)) + min;

    invokeAction(params.callbackActionId, { result });
  },

  invokeAction: (params) => {
    invokeAction(params.actionId, params.params || {});
  },
};

renderUI();