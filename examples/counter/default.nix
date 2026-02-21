{ target, config, ... }:
let

  signum =
    x:
    if x < 0 then
      -1
    else if x > 0 then
      1
    else
      0;
  abs = x: if x < 0 then 0 - x else x;

  #sum = x: if x > 0 then x + sum (x - 1) else if x < 0 then x + sum (x + 1) else 0; # test recursion
  #sum = x: (((abs x) * ((abs x) + 1)) / 2) * (signum x); # test helper functions
  sum = x: if x > 0 then add x (sum (x - 1)) else if x < 0 then add x (sum (x + 1)) else 0; # test currying currying
  add = x: y: x + y;
in
{
  initialState = {
    counter = 0;
  };

  view = [
    (state: {
      elements = [
        {
          content = "Counter: " + state.counter;
          annotations = [ ];
        }
      ];
      actions = [
        {
          content = "Increment";
          actionId = "increment";
          annotations = [ ];
        }
        {
          content = "Decrement";
          actionId = "decrement";
        }
        {
          content = "Increment by";
          actionId = "incrementBy";
        }
        {
          content = "Sum up to counter";
          actionId = "sumUp";
        }
        {
          content = "Reset";
          actionId = "reset";
        }
      ];
    })
  ];

  stateType = {
    _type = "struct";
    fields = {
      counter = {
        _type = "int";
      };
    };
  };

  actions = {
    increment = {
      function =
        { state }:
        {
          state = state // {
            counter = state.counter + 1;
          };
          effect = target.capabilities.effects.noop;
        };
    };

    incrementBy = {
      function =
        { state, params }:
        {
          state = state // {
            counter = state.counter + params.amount;
          };
          effect = target.capabilities.effects.noop;
        };
      paramType = {
        _type = "struct";
        fields = {
          amount = {
            _type = "int";
          };
        };
      };
    };
    decrement = {
      function =
        { state }:
        {
          state = state // {
            counter = state.counter - 1;
          };
          effect = target.capabilities.effects.noop;
        };
    };

    sumUp = {
      function =
        { state }:
        {
          state = state // {
            counter = sum state.counter;
          };
          effect = target.capabilities.effects.noop;
        };
    };

    reset = {
      function =
        { state }:
        {
          state = state // {
            counter = config.initialState.counter;
          };
          effect = target.capabilities.effects.log {
            message = "Counter reset to zero.";
          };
        };
    };
  };
  title = "Counter (Gestalt Example)";
  name = "example-counter";
  version = "0.0.2";
  author.name = "Leonard Menzel";
}
