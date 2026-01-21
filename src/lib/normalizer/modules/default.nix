{lib, config}: {
  config = {
    imports = [
      ./normalizeActions.nix
    ]
  }
  options = {
    normalizeActions = lib.mkOption {
      type = lib.types.any;
      default = true;
      description = "Whether to normalize actions.";
    };
  }
}