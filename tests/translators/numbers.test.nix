[
  {
    description = "devision of integer should round down";
    func = params: params.a / params.b;
    params = {
      a = 5;
      b = 2;
    };
    expected.toBe = 2;
  }
  {
    description = "devision of floats should work as normal";
    func = params: params.a / params.b;
    params = {
      a = 5.0;
      b = 2.0;
    };
    expected.toPass =
      res: builtins.trace "result: ${builtins.toJSON res}" (res < 2.500001 && res > 2.49999);
  }
]
