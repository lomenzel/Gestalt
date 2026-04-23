{
  config,
  lib,
  target,
  ...
}:

let
  inherit (target.components)
    section
    displayValue
    actionGroup
    action
    ;
  inherit (target.effects) Noop Log;
in
{
  meta = {
    name = "example-counter";
    title = "Gestalt Counter";
    version = "0.0.1";
    author.name = "Leonard Menzel";
  };

  init = {
    state = {
      counter = 0;
    };
    effect = Log.info "Counter app initialized with counter = ${builtins.toString config.init.state.counter}";
  };

  view =
    { state, config, ... }:
    {
      page.sections = {
        status = {
          order = 1; # optional. deaults to alphabetical after sections with order
          content = displayValue {
            label = "Counter Value";
            tooltip = "The current value of the counter";
            value = "Counter: ${builtins.toString state.counter}";
          };
        };
        controls = {
          order = 2;
          content = actionGroup {
            actions = {
              increment = action {
                name = "Increment";
                tooltip = "Increase the counter by 1";
                onClick = state: {
                  counter = state.counter + 1;
                }; # result gets deeply merged into state
              };
              decrement = action {
                name = "Decrement";
                tooltip = "Decrease the counter by 1";
                onClick = state: {
                  state.counter = state.counter - 1;
                  effect = Log.info "Counter decremented to ${builtins.toString state.counter}";
                };
                # if has key "state" or "effect" it merges state into state and runs effect.
                # will throw on invalid return value
              };
            };
          };
        };
        page.title = "C: ${builtins.toString state.counter} | Counter Example";
      };
    };
}
