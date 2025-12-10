{
  modules = [
    (
      { target, ... }:
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
          increment =
            { state }:
            {
              state.counter = state.counter + 1;
            };
          decrement =
            { state }:
            {
              state.counter = state.counter - 1;
            };
          sumUp =
            { state }:
            {
              state.counter = sum state.counter;
            };
          reset =
            { state }:
            {
              state.counter = 0;
            };
        };
      }
    )
  ];
  title = "Counter (Gestalt Example)";
  name = "example-counter";
  version = "0.0.1";
  author.name = "Leonard Menzel";
}
