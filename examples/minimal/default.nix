{
  modules = [
    (
      { target, config, ... }:
      let

        add = {x}: {y}: x + y;
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
          i = {
            function =
              { state }:
              {
                state = {
                  counter = add {x = state.counter;} {y = 1;};
                };
                effect = target.capabilities.effects.noop;
              };
          };

        };

      }
    )
  ];
  title = "Minimal Example (Gestalt Example)";
  name = "example-minimal";
  version = "0.0.1";
  author.name = "Leonard Menzel";
}
