{
  modules = [
    (
      { target, config, ... }:
      let
        sum = x: (((abs x) * ((abs x) + 1)) / 2) * (signum x);
        signum =
          x:
          if x < 0 then
            -1
          else if x > 0 then
            1
          else
            0;
        abs = x: if x < 0 then 0 - x else x;

        # todo fix type system to allow ercursive functions
        #sum = x: if x < 0 then 0 else sum x + (x - 1);


      in
      {
        initialState = {
          counter = 0;
        };

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
                effect = target.effects.noop;
              };
          };

          incrementBy = {
            function =
              { state, params }:
              {
                state = state // {
                  counter = state.counter + params.amount;
                };
                effect = target.effects.noop;
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
                effect = target.effects.noop;
              };
          };

          sumUp = {
            function =
              { state }:
              {
                state = state // {
                  counter = sum state.counter;
                };
                effect = target.effects.noop;
              };
          };

          reset = {
            function =
              { state }:
              {
                state = state // {
                  counter = config.initialState.counter;
                };
                effect = target.effects.noop;
              };
          };
        };

      }
    )
  ];
  title = "Counter (Gestalt Example)";
  name = "example-counter";
  version = "0.0.2";
  author.name = "Leonard Menzel";
}
