{
  Effects =
    let
      # the idea is to have a small set of very generic native effects
      # that are platform-specific and then compose and wrap a sane develloper interface
      # on top of them
      # (needs anonymous actions to be effective)
      nativeEffects = {
        httpRequest =
          {
            url,
            method,
            body,
            headers,
            callBackActionId,
          }@params:
          {
            id = "httpRequest";
            description = "Makes an HTTP request.";
            inherit params;
          };
        # actions is type { actionId: string, params: any }[]
        invokeActions = actions: {
          id = "invokeActions";
          description = "Invokes multiple actions in sequence.";
          params = {
            inherit actions;
          };
        };
      };
    in
    rec {
      Log = {
        info = message: {
          description = "Log its parameter to the console.";
          id = "Log";
          params = message;
        };
        warn = message: Log.info "[WARNING] ${message}";
      };
      Noop = {
        description = "Does nothing";
        id = "Noop";
      };

      Store = {
        get = key: callbackActionId: {
          description = "Reads a value from disk by its key. Calles the action with id callbackActionId with the result of type { success: bool, value: any }";
          id = "store.get";
          params = {
            inherit key callbackActionId;
          };
        };
        set = key: value: {
          description = "Writes a value to disk by its key. Overrides if allready present.";
          id = "store.set";
          params = {
            inherit key value;
          };
        };
      };

      # optional arguments to add headers or something would be nice
      # (translators need to support __functor language feature)
      HTTP.get =
        url: callbackActionId:
        nativeEffects.httpRequest {
          inherit url callbackActionId;
          method = "GET";
          body = "";
          headers = [ ];
        };

      Random.int = from: to: callbackActionId: {
        description = "generates a random integer between from and to (inclusive)";
        params = {
          inherit from to callbackActionId;
        };
        id = "Random.int";
      };

      Actions = {
        invoke =
          actionID: params:
          nativeEffects.invokeActions [
            {
              actionId = actionID;
              inherit params;
            }
          ];
      };

      # when anonymous actions are supported Effects.emit
      # or something can map the effects to actions and
      # invoke those without additional nativeEffects

    };
  annotations = {

    Button = {
      primary = {
        name = "primary";
        description = "Indicates that this button is the primary action. Displayed with accent color.";
        allowedOnTypes = [
          { _type = "action"; }
        ];
      };
    };

    Navigation = {
      link = {
        name = "navlink";
        description = "Indicates that this action is a navigation link.";
        allowedOnTypes = [
          { _type = "action"; }
        ];

      };
    };

    Text = {
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
    };

    Progress = {
      bar = {
        name = "progressbar";
        description = ''
          Indicates that this value represents a progress bar.
          The value should be a number between 0 and 1, where 0 is 0% and 1 is 100%.
        '';
        allowedOnTypes = [
          { _type = "number"; }
        ];
      };

      # needs better view system to be effective
      spinner = {
        name = "progressspinner";
        description = ''
          Indicates that this value represents a loading spinner.
          the value is ignored. 
        '';
        allowedOnTypes = [
          { _type = "boolean"; }
        ];
      };
    };
  };

}
