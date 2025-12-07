{ lib, ... }:
{
  options = {
    state = lib.mkOption {
      type = lib.types.attrs;
      default = { };
    };
    actions = lib.mkOption {
      type = lib.types.attrs;
    };
  };
}
