[

  {
    func = params: params.str1 + params.str2;
    params = {
      str1 = "foo";
      str2 = "bar";
    };
    description = "string concatenation using the + operator";
    expected.toBe = "foobar";
  }
  {
    func = params: "${params.greeting} ${params.name}!";
    params = {
      greeting = "Hello";
      name = "World";
    };
    description = "string interpolation should resolve variables correctly";
    expected.toBe = "Hello World!";
  }
]
