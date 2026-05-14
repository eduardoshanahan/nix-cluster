{ lib, ... }:
{
  # Do NOT import sd-image-aarch64.nix here — it declares fileSystems."/"
  # for the SD card root, which conflicts with the SSD root migration.
  # The default root declaration below covers pre-migration nodes;
  # migrated nodes override it via homelab.storage.externalSrv.ssdRoot.

  nixpkgs.hostPlatform = "aarch64-linux";

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;
  boot.supportedFilesystems = lib.mkForce [
    "ext4"
    "vfat"
  ];

  hardware.enableAllHardware = lib.mkForce false;
  hardware.enableRedistributableFirmware = true;

  # Default root: SD card (NIXOS_SD label). Overridden after SSD root migration.
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };
}
