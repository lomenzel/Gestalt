[

  {
    func =
      params:
      let
        b = a * 2;
        a = params.x;
      in
      a + b;
    params = {
      x = 3;
    };
    description = "let bindings can refer to each other";
    expected.toBe = 9;
  }
  {
    func =
      params:
      let
        a = 1;
      in
      let
        a = 2; # Shadowing the outer 'a'
      in
      a + params.val;
    params = {
      val = 5;
    };
    description = "inner let bindings should shadow outer let bindings";
    expected.toBe = 7;
  }
]
