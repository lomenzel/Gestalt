{ lib, ... }:
{
  options = {
    actions = lib.mkOption {
      type = lib.types.attrs;
    };
    initialState = lib.mkOption {
      type = lib.types.attrs;
    };
    stateType = lib.mkOption {
      type = lib.types.attrs;
    };
  };
}
