[

  {
    func = params: if params.condition then params.onTrue else params.onFalse;
    params = {
      condition = true;
      onTrue = "yes";
      onFalse = "no";
    };
    description = "if-then-else evaluates to the true branch when condition is true";
    expected.toBe = "yes";
  }
  {
    func = params: if !params.condition then params.onTrue else params.onFalse;
    params = {
      condition = true;
      onTrue = "yes";
      onFalse = "no";
    };
    description = "if-then-else evaluates to the false branch when condition is false";
    expected.toBe = "no";
  }
  # skipping this test for now since the `with` statement is not yet supported
  # {
  #   func = params: with params; a + b;
  #   params = {
  #     a = 100;
  #     b = 200;
  #   };
  #   description = "with statement should bring attribute set keys into local scope";
  #   expected.toBe = 300;
  # }
]
