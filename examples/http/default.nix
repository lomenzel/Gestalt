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
              annotations = [ target.capabilities.annotations.ui.important ];
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
          effect = target.capabilities.effects.httpRequest {
            method = "GET";
            url = params.url;
            callBackActionId = "handleFetchResult";
          };
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
            text = "Fetched data (status: ${params.status}): ${params.body}";
          };
          effect = target.capabilities.effects.log {
            message = "Data fetched: ${builtins.toJSON (state // { text = "nö";})}";
          };
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
