{
  description = "Placeholder private config for nix-cluster";

  outputs =
    { self, ... }:
    {
      nixosModules.default = import ./modules/shared.nix;
    };
}
