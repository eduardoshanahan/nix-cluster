{ config, lib, pkgs, ... }:
{
  networking.useDHCP = lib.mkDefault true;

  time.timeZone = config.homelab.timezone;

  i18n.defaultLocale = "en_IE.UTF-8";

  users.users.${config.homelab.adminUser} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    git
    curl
    vim
    htop
    kubectl
    k9s
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix.settings.require-sigs = lib.mkDefault true;
  nix.settings.trusted-public-keys = config.homelab.nix.trustedBuilderPublicKeys;

  system.stateVersion = "24.11";
}
