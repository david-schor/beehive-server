{vars, pkgs, ...}: {
      environment.systemPackages = with pkgs; [
        git
        nano
        parted
        efibootmgr
        zfs
        sops
        age
  ];

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = [
      vars.sshPublicKeyPersonal
    ];
  };

  users.motd = ''
    Live ISO Installer

    Copy and paste following cmd!

    sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/david-schor/beehive-server/main/install.sh)"
  '';

  security.sudo.wheelNeedsPassword = false;

  nix.settings.experimental-features = ["nix-command" "flakes"];

  services.openssh = {
    enable = true;
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.11";
}