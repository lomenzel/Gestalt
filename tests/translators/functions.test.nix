[

  {
    func =
      let
        # Destructuring with a default value
        f =
          {
            a,
            b ? 5,
          }:
          a + b;
      in
      params:

      f params;
    params = {
      a = 10;
    };
    description = "function destructuring with missing arguments falling back to defaults";
    expected.toBe = 15;
  }
  {
    func =
      let
        f = args@{ a, ... }: a + args.b;
      in
      params:

      f params;
    params = {
      a = 2;
      b = 3;
      c = 4;
    };
    description = "@ pattern binding and ellipsis (...) should capture all arguments";
    expected.toBe = 5;
  }
  {
    func =
      let
        # Currying
        multiply = x: y: x * y;
      in
      params:

      multiply params.x params.y;
    params = {
      x = 4;
      y = 5;
    };
    description = "calling curried functions should work normally";
    expected.toBe = 20;
  }
]
