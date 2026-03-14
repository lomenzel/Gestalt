[
  {
    func = params: [
      params.first
      params.second
      params.third
    ];
    params = {
      first = 1;
      second = 2;
      third = 3;
    };
    description = "basic list construction";
    expected.toBe = [
      1
      2
      3
    ];
  }
  {
    func = params: params.list1 ++ params.list2;
    params = {
      list1 = [
        1
        2
      ];
      list2 = [
        3
        4
      ];
    };
    description = "list concatenation using the ++ operator";
    expected.toBe = [
      1
      2
      3
      4
    ];
  }
]
