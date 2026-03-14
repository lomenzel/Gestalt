[

  {
    func = params: (params.set1 // params.set2).a;
    params = {
      set1 = {
        a = 1;
        b = 2;
      };
      set2 = {
        a = 10;
        c = 3;
      };
    };
    description = "attribute set update operator (//) should overwrite left values with right values";
    expected.toBe = 10;
  }
  # skipping this test since rec is not yet supported
  # {
  #   func =
  #     params:
  #     (rec {
  #       x = params.base;
  #       y = x + 5;
  #     }).y;
  #   params = {
  #     base = 10;
  #   };
  #   description = "recursive attribute sets (rec) should allow referencing sibling attributes";
  #   expected.toBe = 15;
  # }
  {
    func = { val }: ({ inherit val; }).val;
    params = {
      val = 42;
    };
    description = "inherit keyword should bring variables from scope into an attribute set";
    expected.toBe = 42;
  }
]
