{
  modules = [
    (
      { target, config, ... }:
      {
        initialState = {
          text = "Nothing fetched yet. try fetch action";
        };

        stateType = {
          _type = "struct";
          fields = {
            text = {
              _type = "string";
            };
          };
        };

        actions = {
          fetch = {
            function = {
              state,
              params,
            }:{
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
            function = {
              state,
              params,
            }:{
              state = state // {
                text = "Fetched data (status: ${params.status}): ${params.body}";
              };
              effect = target.capabilities.effects.noop;
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
      }
    )
  ];
  title = "HTTP (Gestalt Example)";
  name = "example-http";
  version = "0.0.1";
  author.name = "Leonard Menzel";
}
