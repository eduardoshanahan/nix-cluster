{ lib, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
  ];

  nixpkgs.hostPlatform = "aarch64-linux";

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;
  boot.supportedFilesystems = lib.mkForce [
    "ext4"
    "vfat"
  ];

  hardware.enableAllHardware = lib.mkForce false;
  hardware.enableRedistributableFirmware = true;
}
