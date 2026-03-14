{ config, lib, ... }:
let
  admin = config.homelab.adminUser;
  adminKeys = config.homelab.adminAuthorizedKeys;
  keyText =
    if adminKeys == [ ]
    then null
    else (builtins.concatStringsSep "\n" adminKeys) + "\n";
in
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowAgentForwarding = "yes";
      AuthorizedKeysFile = "/etc/ssh/authorized_keys/%u";
    };
  };

  users.allowNoPasswordLogin = true;

  environment.etc = lib.mkMerge [
    (lib.mkIf (keyText != null) {
      "ssh/authorized_keys/${admin}" = {
        text = keyText;
        mode = "0644";
      };
    })
  ];

  systemd.tmpfiles.rules = [
    "d /etc/ssh/authorized_keys 0755 root root -"
  ];
}
