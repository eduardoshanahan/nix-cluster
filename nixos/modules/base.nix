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
  nix.settings.substituters = lib.mkAfter [ "https://cache.hhlab.home.arpa" ];
  nix.settings.trusted-public-keys = config.homelab.nix.trustedBuilderPublicKeys ++ [ "homelab-cache-1:4n64FJC4BCb6bhHQYT9vnrSUHwcJI8S7ktDgpHU1I0E=" ];

  services.prometheus.exporters.node = lib.mkIf config.homelab.observability.nodeExporter.enable {
    enable = true;
    port = config.homelab.observability.nodeExporter.port;
    enabledCollectors = [ "systemd" "filesystem" "meminfo" "netdev" "loadavg" "hwmon" ];
  };

  system.stateVersion = "24.11";
}
