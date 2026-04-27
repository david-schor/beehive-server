{ vars, pkgs, ... }: 

{
  environment.systemPackages = with pkgs; [
    age
    cachix
    curl
    efibootmgr
    git
    nano
    parted
    sbctl
    sops
    zfs
  ];

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ vars.sshPublicKeyPersonal ];
  };

  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 5;
    };
    efi.canTouchEfiVariables = true;
    timeout = 10;
  };

  console.keyMap = "sg";

  programs.bash.loginShellInit = ''
    if [ "$USER" = "nixos" ]; then
      sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/david-schor/beehive-server/main/install.sh)"
    fi
  '';

  security.sudo.wheelNeedsPassword = false;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  services.openssh.enable = true;

  system.stateVersion = "25.11";
}