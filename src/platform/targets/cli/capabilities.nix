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
        name = "navigation";
        description = ''
          Indicates that the action will cause a navigation to a different page or view.
        '';
        allowedParamTypes = [ ];
      };
      primary = {
        name = "primary";
        description = ''
          Indicates that this action is a primary action in the UI.
          Rendered with the accent color.
        '';
        allowedParamTypes = [ ];
      };
      danger = {
        name = "danger";
        description = ''
          Indicates a destructive or irreversible action.
          Rendered in red.
        '';
        allowedParamTypes = [ ];
      };
      success = {
        name = "success";
        description = ''
          Indicates a positive or confirming action.
          Rendered in green.
        '';
        allowedParamTypes = [ ];
      };
      outlined = {
        name = "outlined";
        description = ''
          Renders the action button with an outlined style instead of filled.
        '';
        allowedParamTypes = [ ];
      };
    };

    ui = {
      important = {
        name = "important";
        description = ''
          Indicates that this value is important.
          Displayed with accent color and bold weight.
        '';
        allowedOnTypes = [
          { _type = "string"; }
        ];
      };

      muted = {
        name = "muted";
        description = ''
          Secondary or less-important text.
          Displayed in a dimmed color.
        '';
        allowedOnTypes = [
          { _type = "string"; }
        ];
      };

      code = {
        name = "code";
        description = ''
          Displayed in a monospace font with a subtle background.
        '';
        allowedOnTypes = [
          { _type = "string"; }
        ];
      };

      heading = {
        name = "heading";
        description = ''
          Displayed as a prominent heading.
        '';
        allowedOnTypes = [
          { _type = "string"; }
        ];
      };

      tooltip = {
        name = "tooltip";
        description = ''
          Hidden by default.
          User can toggle tooltips globally.
        '';
        allowedOnTypes = [
          { _type = "string"; }
        ];
      };
    };
  };

}
