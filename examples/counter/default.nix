{
  modules = [
    (
      { target, ... }:
      let
        sum = x: if x < 0 then 0 else x + sum (x - 1);
      in
      {
        state.counter.initialValue = 0;

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
