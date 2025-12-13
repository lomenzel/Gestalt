{ lib, ... }:
{
  options = {
    stateType = lib.mkOption {
      type = lib.types.attrs;
      description = "The type of state representation to use.";
    };
    initialState = lib.mkOption {
      type = lib.types.attrs;
      description = "The initial state of the application.";
    };
    actions = lib.mkOption {
      type = lib.types.attrs;
    };
    types = lib.mkOption {
      type = lib.types.attrs;
      default = { };
    };
  };
}
