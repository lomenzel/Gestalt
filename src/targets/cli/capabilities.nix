{
  effects = {
    log = params: {
      description = "Log its parameter to the console.";
      paramType = {
        _type = "string";
      };
      callBackParamType = {
        _type = "never";
      };
      id = "log";
      params = params;
    };
    noop = {
      description = "Does nothing";
      id = "noop";
    };
    httpRequest = params: {
      description = "Makes an HTTP request.";
      paramType = {
        _type = "struct";
        fields = {
          url = {
            _type = "string";
          };
          method = {
            _type = "string";
          };
          body = {
            _type = "string";
          };
          headers = {
            # TODO map type or something
          };
          callBackActionId = {
            _type = "string";
          };
        };
      };
      callBackParamType = {
        # TODO variant type would be nice to have here
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
      id = "httpRequest";
      params = params;
    };

    random =
      {
        from,
        to,
        callbackActionId,
      }@params:
      {
        description = "generates a random integer between from and to (inclusive)";
        paramType = {
          _type = "struct";
          fields = {
            from = {
              _type = "int";
            };
            to = {
              _type = "int";
            };
            callbackActionId = {
              _type = "string";
            };
          };
        };
        inherit params;
        id = "random";
        callBackParamType = {
          _type = "struct";
          fields = {
            result = {
              _type = "int";
            };
          };
        };
      };

    invokeAction = params: {
      description = "Invokes another action";
      paramType = {
        _type = "struct";
        fields = {
          actionId = {
            _type = "string";
          };
          params = {
            _type = "jsonvalue";
          };
        };
      };
      callBackParamType = {
        _type = "jsonvalue";
      };
      id = "invokeAction";
      params = params;
    };

  };
  annotations = {
    actions = {
      navigation = {
        description = ''
          Indicates that the action will cause a navigation to a different page or view.
          will generate a keyboard shortcut for the action
        '';
        allowedParamTypes = [ ];
      };
      primary = {
        description = ''
          Indicates that this action is a primary action in the UI
          will display a keyboard shortcut for the action in the UI
        '';
        allowedParamTypes = [ ];
      };
    };

    ui = {
      important = {
        description = ''
          Indicates that this value is important
          will display text in accent color
        '';
        allowedOnTypes = [
          { _type = "string"; }
        ];
      };

      tooltip = {
        description = ''
          hidden by default
          user can toggle tooltips globally
        '';
        allowedOnTypes = [
          { _type = "string"; }
        ];
      };
    };
  };

}
