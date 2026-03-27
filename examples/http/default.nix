{ target, config, ... }:
{
  view = [
    (state: {
      elements =
        if builtins.hasAttr "text" state then
          [
            {
              content = state.text;
              annotations = [ ];
            }
          ]
        else
          [
            {
              content = "no text in state :()";
              annotations = [ target.capabilities.annotations.Text.important ];
            }
          ];
      actions = [
        {
          content = "Fetch Data";
          annotations = [ ];
          actionId = "fetch";
        }
      ];
    })
  ];

  actions = {
    fetch = {
      function =
        {
          state,
          params,
        }:
        {
          state = state;
          effect = target.capabilities.Effects.HTTP.get params.url "handleFetchResult";
        };
      paramType = {
        _type = "struct";
        fields = {
          url = {
            _type = "string";
          };
        };
      };
    };
    handleFetchResult = {
      function =
        {
          state,
          params,
        }:
        {
          state = state // {
            text = "Fetched data (status: ${builtins.toString params.status}): ${params.body}";
          };
          effect = target.capabilities.Effects.Noop;
        };
      paramType = {
        _type = "struct";
        fields = {
          status = {
            _type = "int";
          };
          body = {
            _type = "string";
          };
          headers = {
            _type = "string";
          };
        };
      };
    };
  };
  title = "HTTP (Gestalt Example)";
  name = "example-http";
  version = "0.0.1";
  author.name = "Leonard Menzel";
}
